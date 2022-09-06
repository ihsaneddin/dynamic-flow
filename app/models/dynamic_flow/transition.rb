module DynamicFlow
  class Transition < ApplicationRecord

    belongs_to :workflow, touch: true
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

    delegate :config, to: :transition_trigger
    delegate :sub_workflow, to: :transition_trigger

    alias_method :trigger=, :transition_trigger_attributes=

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

    def can_be_fired?(instance, task = nil)
      ins = arcs.in.to_a
      return false if ins.blank?
      can = if task
        if task.enabled?
          ins.all? { |arc| arc.place.tokens.where(instance: instance).free.exists? }
        elsif task.started?
          ins.all? { |arc| arc.place.tokens.where(instance: instance).locked.exists? }
        end
      else
        ins.all? { |arc| arc.place.tokens.where(instance: instance).free.exists? }
      end
    end

    def enable! instance
      # unless can_be_fired? instance
        tasks.enabled.where(instance: instance).each do |task|
          task.override!(instance) if task.may_override? instance
        end
      # end
      if can_be_fired?(instance) && !tasks.where(instance: instance, state: %w[enabled started]).exists?
        task = instance.tasks.build(workflow: instance.workflow, transition: self)
        task.save
        task.enable!
        perform_callback(callback_name: :enabled, payload: { transition_id: self.id, instance_id: instance.id })
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
          if task.pass_guard?(arc, has_passed)
            has_passed = true
            instance.create_token arc.place
          end
        else
          instance.create_token arc.place
        end
      end
      ##callback for transition fired
      if has_passed
        perform_callback(callback_name: :fired, payload: { transition_id: self.id, instance_id: instance.id, task_id: task.id })
      else
        perform_callback(callback_name: :fired_failed, payload: { transition_id: self.id, instance_id: instance.id, task_id: task.id })
      end
    end

    def set_dynamic_assignments instance, transition_id, actor_id
      t = dynamic_assignments.find(transition_id)
      if t
        instance.add_manual_assignment t, DynamicFlow::Actor.find(actor_id)
      end
    end

    def get_default_assignees task
      perform_callback(callback_name: :default_task_assignees, payload: { task_id: task.id })
    end

    def eval_finish_condition parent_task, instance
      return true unless finish_condition.present?
      finish_condition.check_expression self, parent_task, instance
    end

    class FinishCondition < Document::FieldOptions

      attribute :ruby_expression, :string, default: ""
      attribute :js_expression, :string, default: ""

      def check_expression transition, parent_task, instance
        if ruby_expression.present?
          eval_ruby_expression transition, parent_task, instance
        else
          if js_expression.present?
            eval_js_expression transition, parent_task, instance
          else
            default_evaluation transition, parent_task, instance
          end
        end

      end

      def default_evaluation transition, parent_task, instance
        parent_task.children.all?{|task| task.finished?}
      end

      def eval_ruby_expression transition, parent_task, instance
        result = DynamicFlow::ScriptEngine.run_inline expression, payload: { task: parent_task.as_json }
        if result.errors.any?
          DynamicFlow.raise_exception type: :ruby_expression, message: I18n.t("dynamic_flow.expression.ruby.error", e: result.errors)
        end
        ActiveModel::Type::Boolean.new.cast(result.output)
      rescue => e
        DynamicFlow.raise_exception type: :ruby_expression, message: I18n.t("dynamic_flow.expression.ruby.error", e: e.message)
      end

      def eval_js_expression transition, parent_task, instance
        context = MiniRacer::Context.new(timeout: 1000, max_memory: 200_000_000)
        context.eval("let task = #{parent_task.as_json};")
        result = context.eval(expression)
        ActiveModel::Type::Boolean.new.cast(result)
      rescue => e
        DynamicFlow.raise_exception type: :javascript_expression, message: I18n.t("dynamic_flow.expression.javascript.error", e: e.message)
      end

    end

    serialize :finish_condition, FinishCondition

    def perform_callback callback_name:, payload: {}
      callback = config.callbacks.filter{|c| c.name == callback_name.to_s }.first
      DynamicFlow.perform_transition_callback(callback_name: callback_name.to_sym, payload: payload, class_name:callback.try(:class_name), delayed: callback.try(:delayed) )
    end

  end
end