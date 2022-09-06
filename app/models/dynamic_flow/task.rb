module DynamicFlow
  class Task < ApplicationRecord
    belongs_to :workflow
    belongs_to :transition
    belongs_to :instance
    belongs_to :parent, class_name: "DynamicFlow::Task", optional: true, counter_cache: :children_count
    belongs_to :holding_user, foreign_key: :holding_user_id, class_name: DynamicFlow.user_class, optional: true
    has_many :task_assignments
    has_many :actors, through: :task_assignments, source: "actor"
    has_many :entries, class_name: DynamicFlow.entry_class
    has_one :started_instance, foreign_key: :started_by_task_id, class_name: "DynamicFlow::Instance"
    has_many :children, foreign_key: :parent_id, class_name: "DynamicFlow::Task"

    include AASM

    aasm column: :state do

      error_on_all_events do |e|
        DynamicFlow.delegate_exception e
      end

      state :created, initial: true
      state :enabled
      state :started
      state :canceled
      state :finished
      state :overriden

      event :enable, guards: [:is_instance_active?] do
        after do
          after_enable_callback
        end
        transitions from: [:created], to: :enabled
      end

      event :start, guards: [:is_instance_active?] do
        transitions from: [:enabled], to: :started, guards: :start_guard
        after do |user|
          after_start_callback user
        end
      end

      event :cancel, guards: [:is_instance_active?] do
        transitions from: [:started], to: :cancel
        after do
          after_cancel_callback
        end
      end

      event :override, guards: [:is_instance_active?] do
        transitions from: [:enabled], to: :overriden
        after do
          after_override_callback
        end
      end

      event :finish, guards: [:is_instance_active?, :is_transition_can_be_fired?] do
        transitions from: [:started, :overriden], to: :finished, guards: [:finish_guard, :multiple_instance_finish_guard]
        after do |user|
          after_finish_callback user
        end
      end

    end

    ### START of aasm callback methods
    def after_enable_callback
      delay_time_task
      set_task_assignments
      transition.perform_callback(callback_name: :task_enabled, payload: { task_id: self.id })
      start! if transition.trigger_type == "automatic"
    end

    def start_guard user = nil
      return true if automatic_or_time?
      return true if transition.trigger_type == 'sub_workflow' && !transition.config.strict
      return true if transition.multiple_instance && parent?
      return user.is_a?(DynamicFlow.user_class_constant) && started_by?(user)
    end

    def after_start_callback user = nil
      transition.arcs.in.each do |arc|
        instance.lock_token arc.place, self
      end
      if forked?
        if parent.may_start?
          parent.start!
        end
      end
      if automatic_or_time?
        finish!
      else
        update holding_user: user
      end
      create_and_activate_sub_workflow
      transition.perform_callback(callback_name: :task_started, payload: { task_id: self.id })
    end

    def finish_guard user = nil
      return true if automatic_or_time?
      return true if transition.multiple_instance && parent?
      if transition.trigger_type == 'sub_workflow'
        return started_instance.finished? if transition.config.strict?
      end
      pass = user.is_a?(DynamicFlow.user_class_constant) && finished_by?(user)
      if transition.trigger_type == 'user'
        form = transition.transition_trigger.form
        entry = entries.where(user_id: user.id, form_id: form.id).last
        pass = pass && entry.try(:payload_id).present?
      end
      pass
    end

    def multiple_instance_finish_guard
      if forked?
        parent.multiple_instance_finish_condition_passed?
      else
        multiple_instance_finish_condition_passed?
      end
    end

    def after_finish_callback user = nil
      stamps :finished_at
      if transition.multiple_instance
        if parent?
          children.where(state: %w[started enabled]).find_each do |task|
            task.override!
          end
          transition.fire! self, aasm.from_state.to_sym == :started
          if instance.is_at_end_place?
            instance.finish!
          end
          instance.enable_transitions! unless instance.finished?
        else
          DynamicFlow::Task.increment_counter(:children_finished_count, parent_id)
          if parent.may_finish?
            parent.finish!
          end
        end
      else
        transition.fire! self, aasm.from_state.to_sym == :started
        if instance.is_at_end_place?
          instance.finish!
        end
        instance.enable_transitions! unless instance.finished?
      end
      transition.perform_callback(callback_name: :task_finished, payload: { task_id: self.id })
    end

    def after_override_callback
      stamps :overriden_at
      transition.perform_callback(callback_name: :task_overriden, payload: { task_id: self.id })
    end

    def after_cancel_callback
      stamps :canceled_at
      instance.release_token task
      if parent?
        children.where(state: %w[started enabled]).find_each do |task|
          task.cancel!
        end
        transition.enable!
      end
      transition.perform_callback(callback_name: :task_canceled, payload: { task_id: self.id })
    end
    ### END of aasm callback methods


    ### START of core methods
    def multiple_instance_finish_condition_passed?
      if parent?
        transition.eval_finish_condition(self, instance)
      else
        transition.eval_finish_condition(parent, instance)
      end
    end

    def create_and_activate_sub_workflow
      if transition.trigger_type == 'sub_workflow'
        sub_instance = transition.transition_trigger.sub_workflow.instances.create!( started_by_task: self )
        sub_instance.activate!
      end
    end

    def is_instance_active?
      instance && instance.active?
    end

    def is_transition_can_be_fired?
      instance && transition.can_be_fired?(instance, self)
    end

    def parent?
      !forked
    end

    def pass_guard?(arc, has_passed = false)
      if arc.guards_count == 0
        !has_passed
      else
        entry = entries.where(user: holding_user).first
        arc.guards.all? { |guard| guard.pass?(entry, self) }
      end
    end

    def real?
      return false if transition.multiple_instance? && parent_id.nil?
      # return false if transition.sub_workflow.present?
      true
    end

    def automatic_or_time?
      ["automatic", "time"].include?(transition.trigger_type)
    end

    def started_by?(user)
      real? && owned_by?(user)
    end

    def finished_by?(user)
      real? && owned_by?(user) && holding_user == user
    end

    def owned_by?(user)
      actor = user.try :actor
      if forked?
        parent.actors.where(id: actor.try(:id)).exists?
      else
       actors.where(id: actor.try(:id)).exists?
      end
      # DynamicFlow::Actor.joins(task_assignments: { task: [{:transition => [:transition_trigger]}, :instance] })
      #          .where(DynamicFlow::TransitionTrigger.table_name => { type:  ["DynamicFlow::TransitionTriggers::User", "DynamicFlow::TransitionTriggers::Manual", "DynamicFlow::TransitionTriggers::SubWorkflow"]})
      #          .where(DynamicFlow::Instance.table_name => { state: "active" })
      #          .where(DynamicFlow::Task.table_name => { state: %w[started enabled] })
      #          .where(DynamicFlow::Task.table_name => { id: id }).map do |actor|
      #   actor.context.users.to_a
      # end.flatten.include?(user)
    end

    def name
      "Task -> #{id}"
    end

    def stamps att
      update_column att, Time.zone.now
    end

    def delay_time_task
      if transition.trigger_type == 'time'
        _trigger_time = Time.zone.now + transition.transition_trigger.config.delay_in_seconds.seconds
        update_column(:trigger_time, _trigger_time)
        DynamicFlow::TaskWorker.set(wait: transition.transition_trigger.config.delay_in_seconds.seconds.in_minutes.minutes).perform_later(id, :start)
      end
    end

    def set_task_assignments
      has_assignments = false
      instance.instance_assignments.where(transition: transition).find_each do |ia|
        add_task_assignment ia.actor
        has_assignments = true
      end
      unless has_assignments
        default_actors = get_default_actors
        if default_actors.present?
          default_actors.each do |actor|
            add_task_assignment actor, false
          end
        else
          transition.transition_static_assignments.each do |static_assignment|
            add_task_assignment static_assignment.actor, false
          end
        end
      end
      if task_assignments.blank? && !automatic_or_time?
        ##callback for empty assignment
        transition.perform_callback(callback_name: :task_unassigned, payload: { task_id: self.id })
      end
    end

    def get_default_actors
      transition.get_default_assignees(self) || []
    end

    def add_task_assignment actor, permanent = false
      return if actor.nil?
      add_manual_assignment actor if permanent
      return if actors.include?(actor)
      task_assignments.create!(actor: actor)
      transition.perform_callback(callback_name: :task_assigned, payload: { task_id: self.id, actor_id: actor.id })
      new_assignables = task_assignments.map do |ta|
        ta.actor.context.respond_to?(:users) ? ta.actor.context.users.to_a : []
      end.flatten
      new_assignables.each do |user|
        if transition.multiple_instance && !forked
          next if children.where(holding_user: user).exists?
          child = children.create!(
            workflow_id: workflow_id,
            transition_id: transition_id,
            trigger_time: trigger_time,
            forked: true,
            holding_user: user,
            instance_id: instance_id,
            state: state
          )
          ##callback for automatic assignment for multiple instance transition
          transition.perform_callback(callback_name: :task_assigned, payload: { task_id: self.id, user_id: user.id })
        end
      end
    end

    def add_manual_assignment actor
      instance.add_manual_assignment transition, actor
    end

    def create_entry user, atts
      if transition.trigger_type == 'user'
        form = transition.transition_trigger.form
        entry = entries.find_or_initialize_by(user_id: user.id, form_id: form.id)
        vmodel = form.to_virtual_model
        if entry.payload_id
          object = vmodel.find entry.payload_id
        end
        object ||= vmodel.new atts
        object.new_record?? object.save : object.update(atts)
        unless object.errors.any?
          entry.update_payload object
        end
        object
      end
    end

    def as_json *args
      if args.present?
       super
      else
        super.merge(holding_user: holding_user ? holding_user.as_json : {}, entries: entries.map{|e| e.as_json })
      end
    end

    def to_json *args
      if args.present?
       super
      else
        as_json.to_json
      end
    end

    ### END of core methods

    class << self

      def todo(user)
        current_actor_ids = [user, DynamicFlow.group_classes.map { |method, _group_class| user&.public_send(method) }].flatten.map { |g| g&.actor&.id }.compact
        DynamicFlow::Task.where(forked: false).joins(:task_assignments).where(DynamicFlow::TaskAssignment.table_name => { actor_id: current_actor_ids })
      end

      def doing(user)
        where(holding_user: user).where(state: %i[started enabled])
      end

      def done(user)
        where(holding_user: user).where(state: [:finished])
      end

    end

  end
end
