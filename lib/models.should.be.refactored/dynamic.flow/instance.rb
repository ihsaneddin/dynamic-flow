module DynamicFlow
  class Instance < ApplicationRecord
    belongs_to :workflow
    belongs_to :targetable, optional: true, polymorphic: true
    belongs_to :started_by_task, optional: true, class_name: "DynamicFlow::Task"
    has_many :tasks
    has_many :tokens
    has_many :instance_assignments
    has_many :actors, through: :instance_assignments, source: "actor"

    include DynamicFlow::Concerns::AasmErrorHandling

    include AASM

    aasm column: :state do

      state :created, initial: true
      state :active
      state :suspended
      state :canceled
      state :finisihed

      event :activate do
        transitions from: [:created, :suspended, :canceled], to: :active do
          guard do
            activation_guard
          end
          after do
            after_activation_callback
          end
        end
        error do |e|
          handle_aasm_invalid_transition_exception e do
            DynamicFlow::Errors.raise_exception! :instance_transition, "dynamic_flow.instance.transition.errors.can_not_be_activated"
          end
        end
      end
      event :suspend do
        transitions from: [:active], to: :suspended
      end
      event :cancel do
        transitions from: [:active, :suspended], to: :suspended
      end
      event :resume do
        transitions from: [:canceled, :suspended], to: :active
      end
      event :finish do
        transitions from: [:active], to: :finished do
          guard do
            finish_guard
          end
          before do
            before_finish_callback
          end
          after do
            after_finish_callback
          end
        end
        error do |e|
          handle_aasm_invalid_transition_exception e do
            if _misconstructed
              self._misconstructed = false
              DynamicFlow::Errors.raise_exception! :instance_transition, "dynamic_flow.instance.transition.errors.misconstructed"
            else
              DynamicFlow::Errors.raise_exception! :instance_transition, "dynamic_flow.instance.transition.errors.can_not_be_finished_yet"
            end
          end
        end
      end
    end

    def finish_guard
      is_end_place_token_present?
    end

    attr_accessor :_misconstructed

    def is_end_place_token_present?
      end_place = workflow.places.end.first
      end_place_token = DynamicFlow::ApplicationRecord.uncached {  tokens.where(place: end_place).count } > 0
      if end_place_token
        free_and_locked_token_count = tokens.where(place: end_place).where(state: %w[free locked]).count
        self._misconstructed = free_and_locked_token_count > 0
      end
      end_place_token && !self._misconstructed
    end

    def is_misconstructed?
      free_and_locked_token_count = tokens.where(place: end_place).where(state: %w[free locked]).count
    end

    def activation_guard
      is_workflow_valid?
    end

    def is_workflow_valid?
      workflow.is_valid
    end

    def after_activation_callback
      create_token workflow.places.start.first
      run_through_automatic_transitions
    end

    def before_finish_callback
      end_place = workflow.places.end.first
      instance.tokens.where(id: tokens.where(place: end_place).free.first&.id ).find_each do |token|
        token.consume!
      end
      if started_by_task
        started_by_task.finish!
      end
    end

    def after_finish_callback

    end

    def run_through_automatic_transitions
      enable_transitions!
      done = false
      until done
        done = true
        if may_finish?
          finish!
        end
        next if finished?
        DynamicFlow::ApplicationRecord.uncached do
          tasks.joins(:transition => [:transition_trigger]).enabled.where(DynamicFlow::TransitionTrigger.table_name => { type: DynamicFlow::TransitionTriggers::Time.name }).find_each do |task|
            task.start!
            done = false
          end
        end
        enable_transitions!
      end
    end

    def enable_transitions!
      workflow.transitions.each do |transition|
        transition.enable! self
      end
    end

    def create_token place
      tokens.create! place: place
    end

    def release_token task
      DynamicFlow::Token.where(locked_task_id: task.id).locked.each do |token|
        token.cancel!
      end
    end

    def consume_token place, locked_task=nil
      if locked_task
        tokens.where(place: place, locked_task_id: locked_task.id).locked.find_each do |token|
          token.consume!
        end
      else
        tokens.where(id: tokens.where(place: place).free.first&.id ).find_each do |token|
          token.consume!
        end
      end
    end

    def lock_token place, task
      tokens.free.where(place: place).limit(1).each do |token|
        token.to_lock! task
      end
    end

    def can_fire?(transition)
      ins = transition.arcs.in.to_a
      return false if ins.blank?

      ins.all? { |arc| arc.place.tokens.where(instance: self).free.exists? }
    end

    def name
      "Instance->#{id}"
    end

    def add_manual_assignment(transition, actor)
      instance_assignments.find_or_create_by!(transition: transition, actor: actor)
    end

    def sweep_automatic_transitions
      enable_transitions
      done = false
      until done
        done = true
        result = finished_p
        tasks.join(:transition => [:transition_trigger]).enabled.where(DynamicFlow::TransitionTrigger.table_name => { type: "DynamicFlow::TransitionTriggers::Automatic" }).find_each do |task|
          task.start! if task.may_start?
        end
      end
    end

    def enable_transitions
      transaction do
        tasks.enabled.each do |task|
          task.override! if task.task.may_override? self
        end
        transitions.each do |transition|
          next unless can_fire?(transition) && !transition.tasks.where(instance: self, state: %w[enabled started]).exists?
          task = tasks.build(workflow: workflow, transition: transition)
          trigger_time = Time.zone.now + transition.transition_trigger.config.delay_in_seconds.seconds
          task.trigger_time = trigger_time if trigger_time
          task.save!
          if task.task_assignments.blank?
            if transition.config && transition.config.task_assignment_empty_callback
              transition.config.task_assignment_empty_callback.constantize.new(task.id).perform_later
            else
              DynamicFlow.run_callback_for(:task_assignment_empty_callback, task)
            end
            DynamicFlow::Notification.instrument( type: "task_assignment_empty_callback", event: { task: task })
          end
          if sub_workflow = transition.sub_workflow
            sub_instance = sub_workflow.instances.create!( started_by_task: task )
            sub_instance.activate!
          end
        end
      end
    end

    def finished_p
      return true if finished?
      end_place = workflow.places.end.first
      end_place_token_count = DynamicFlow::ApplicationRecord.uncached {  tokens.where(place: end_place).count }
      if end_place_token_count == 0
        false
      else
        free_and_locked_token_count= tokens.where(place: end_place).where(state: %w[free locked]).count
        if free_and_locked_token_count > 1
          raise DynamicFlow::Errors::InstanceTransitionError, I18n.t("dynamic_flow.instance.transition.errors.misconstructed")
        end
      end
    end

  end
end
