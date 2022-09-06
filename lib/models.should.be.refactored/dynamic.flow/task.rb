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

    include DynamicFlow::Concerns::AasmErrorHandling

    include AASM

    aasm column: :state do

      error_on_all_events :handle_transition_error

      state :enabled, initial: true
      state :started
      state :canceled
      state :finished
      state :overriden

      event :start, guards: [:is_instance_active?] do
        transitions from: [:enabled], to: :started do
          guard do |user|
            start_transition_guard user
          end
          after do |user|
            after_start_transition
          end
        end
        error do
          handle_aasm_invalid_transition_exception e do
            DynamicFlow::Errors.raise_exception! :task, "dynamic_flow.task.transition.errors.start_error"
          end
        end
      end

      event :cancel, guards: [:is_instance_active?] do
        transitions from: [:started], to: :cancel do
          after do
            after_cancel_transition
          end
        end
      end

      event :override do
        transitions from: [:enabled], to: :overriden do
          guard do |instance|
            !(instance && transition.can_be_fired?(instance))
          end
          after do
            stamp_overriden_at!
          end
        end
      end

      event :finish, guards: [:is_instance_active?, :is_transition_can_be_fired?] do
        transitions from: [:started, :overriden], to: :finished do
          guard do |user|
            finish_transition_guard user
          end
          after do |user|
            after_finish_transition user
          end
        end
      end

    end

    after_create :set_task_assignments

    def handle_transition_error e
      handle_aasm_invalid_transition_exception e do
        if real?
          DynamicFlow::Errors.raise_exception! :task, "dynamic_flow.task.transition.errors.real_error"
        elsif !is_transition_can_be_fired?
          DynamicFlow::Errors.raise_exception! :transition, "dynamic_flow.task.transition.errors.transition_can_not_be_fired"
        elsif !is_instance_active?
          DynamicFlow::Errors.raise_exception! :transition, "dynamic_flow.task.transition.errors.instance_is_not_active"
        else
          e
        end
      end
    end

    def start_transition_guard user
      return true if automatic_or_time?
      return user.is_a?(DynamicFlow.user_class_constant) && started_by?(user)
    end

    def after_start_transition user
      if automatic_or_time?
        finish!
      else
        transition.arcs.in.each do |arc|
          instance.lock_token arc.place, self
        end
      end
    end

    def after_cancel_transition
      stamps :canceled_at
      instance.release_token task
      instance.run_through_automatic_transitions
    end

    def finish_transition_guard user
      return true if automatic_or_time?
      return true if started_instance
      return user.is_a?(DynamicFlow.user_class_constant) && finished_by?(user)
    end

    def after_finish_transition user
      stamp_finished_at!
      transition.fire! self, task.aasm.from_state.to_sym == :started
    end

    def is_instance_active?
      instance.active?
    end

    def is_transition_can_be_fired?
      !(instance && transition.can_be_fired?(instance))
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
      return false if transition.sub_workflow_id.present?
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
      DynamicFlow::Actor.joins(task_assignments: { task: [{:transition => [:transition_triggers]}, :instance] })
               .where(DynamicFlow::TransitionTrigger.table_name => { type:  "DynamicFlow::TransitionTriggers::User"})
               .where(DynamicFlow::Instance.table_name => { state: DynamicFlow::Instance.states[:active] })
               .where(DynamicFlow::Task.table_name => { state: DynamicFlow::Task.states.values_at(:started, :enabled) })
               .where(DynamicFlow::Task.table_name => { id: id }).map do |actor|
        actor.context.users.to_a
      end.flatten.include?(user)
    end


    def name
      "Task -> #{id}"
    end

    def stamp_overriden_at!
      update_column :overriden_at, Time.zone.now
    end

    def stamp_finished_at!
      update_column :finished_at, Time.zone.now
    end

    def stamps att
      update_column att, Time.zone.now
    end

    def set_task_assignments
      has_assignments = false
      instance.instance_assignments.where(transition: transition).find_each do |ia|
        add_task_assignment ia.actor
        has_assignments = true
      end
      unless has_assignments
        default_actors = DynamicFlow.run_callback_for :default_actors_assignment_callback, self
        if transition && transition.config && transition.config.default_actors_assignment_callback
          added = transition.config.default_actors_assignment_callback.constantize.new.perform(self.id)
          unless added.blank?
            default_actors += added
          end
        end
        if default_actors.present?
          default_actors.each do |actor|
            add_task_assignment actor, false
          end
        else
          transition.transition_static_assighments.each do |static_assignment|
            add_task_assignment static_assignment.actor, false
          end
        end
      end
      if transition.trigger_type == 'time'
        debugger
        _trigger_time = Time.zone.now + transition.transition_trigger.config.delay_in_seconds.seconds
        update_column(trigger_time: _trigger_time)
        DynamicFlow::TaskWorker.set(wait: transition.transition_trigger.config.delay_in_seconds.in_minutes.minutes).perform_later(task.id, :start)
      end

      if task_assignments.blank?
        if transition.config && transition.config.task_assignment_empty_callback
          transition.config.task_assignment_empty_callback.constantize.new(self.id).perform_later
        else
          DynamicFlow.run_callback_for(:task_assignment_empty_callback, self)
        end
        DynamicFlow::Notification.instrument( type: "task_assignment_empty_callback", event: { task: self })
      end

    end

    def add_task_assignment actor, permanent = false
      return if actor.nil?
      if permanent
        add_manual_assignment actor
      end

      notified_notifiables = actors.map do |a|
        a.context.respond_to?(:notifiables) ? a.context.notifiables : []
      end.flatten

      assign = task_assignments.where(actor: actor).first
      return if assign
      task_assignments.create!(actor: actor)
      new_notifiables = actor.context.respond_to?(:notifiables) ? actor.context.notifiables : []
      to_be_notified = new_notifiables - notified_notifiables
      to_be_notified.each do |notifiable|
        if transition.multiple_instance && !forked?
          next if children.where(holding_user: notifiable).exists?
          child = children.create!(
            workflow_id: workflow_id,
            transition_id: transition_id,
            trigger_time: trigger_time,
            forked: true,
            holding_user: notifiable,
            instance_id: instance_id
          )
          DynamicFlow::Notification.instrument( type: "notify_task_assignment_callback", event: { notifiable: notifiable, task: child })
          if transition.config && transition.config.notify_task_assignment_callback
            transition.config.notify_task_assignment_callback.constantize.new(child.id, notifiable.id).perform_later
          else
            DynamicFlow.run_callback_for(:notify_task_assignment_callback, child, notifiable)
          end
        else
          DynamicFlow::Notification.instrument( type: "notify_task_assignment_callback", event: { notifiable: notifiable, task: self })
          if transition.config && transition.config.notify_task_assignment_callback
            transition.config.notify_task_assignment_callback.constantize.new(self.id, notifiable.id).perform_later
          else
            DynamicFlow.run_callback_for(:notify_task_assignment_callback, self, notifiable)
          end
        end
      end
    end

    def add_manual_assignment actor
      instance.add_manual_assignment transition, actor
    end

    def clear_task_assignments permanent= true
      transaction do
        clear_manual_assignments if permanent
        task_assignments.delete_all

      end
    end

    def clear_manual_assignments
      instance.instance_assignments.where(transition: transition).find_each &:destroy
    end

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
