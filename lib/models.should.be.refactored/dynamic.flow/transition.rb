module DynamicFlow
  class Transition < ApplicationRecord

    belongs_to :workflow, touch: true
    belongs_to :sub_workflow, optional: true, class_name: "DynamicFlow::Workflow"
    has_one :transition_trigger, dependent: :destroy
    has_many :arcs
    has_many :tasks
    has_many :transition_static_assignments
    has_many :static_actors, through: :transition_static_assignments, source: "actor"
    belongs_to :dynamic_assign_by, optional: true, class_name: "DynamicFLow::Transition"
    has_many :dynamic_assignments, class_name: "DynamicFLow::Transition", foreign_key: "dynamic_assign_by_id"

    accepts_nested_attributes_for :transition_trigger, allow_destroy: true

    validates :name, presence: true
    validates :transition_trigger, presence: true

    def is_sub_workflow?
      !!sub_workflow_id
    end

    def explicit_or_split?
      arcs.out.sum(:guards_count) >= 1
    end

    def graph_id
      "#{name}/#{id}"
    end

    def trigger_type
      transition_trigger.class.name.demodulize.underscore
    end

    def can_be_fired?(instance)
      ins = transition.arcs.in.to_a
      return false if ins.blank?
      ins.all? { |arc| arc.place.tokens.where(instance: instance).free.exists? }
    end

    def enable! instance
      unless can_be_fired? instance
        tasks.enabled.where(instance: instance).each do |task|
          task.override!(instance) if task.task.may_override? instance
        end
      end
      if can_be_fired?(instance) && !tasks.where(instance: instance, state: %w[enabled started]).exists?
        task = instance.tasks.build(workflow: instance.workflow, transition: self)
        task.save!
        if sub_workflow = sub_workflow
          sub_instance = sub_workflow.instances.create!( started_by_task: task )
          sub_instance.activate!
        end
      end
    end

    def fire! task, locked = false
      instance = task.instance
      arcs.each do |arc|
        instance.consume_token arc.place, locked ? task : nil
      end
      has_passed = false
      arcs.out.guards_count_desc.each do |arc|
        if explicit_or_split?
          if pass_guard?(arc, has_passed)
            has_passed = true
            instance.create_token arc.place
          end
        else
          instance.create_token arc.place
        end
      end
      if config && config.fire_transition_callback
        config.fire_transition_callback.constantize.new(self.id, task.id).perform_later
      else
        DynamicFlow.run_callback_for(:fire_transition_callback, self, task)
      end
      DynamicFlow::Notification.instrument( type: "transition", event: { transition: self, task: task })
    end

  end
end