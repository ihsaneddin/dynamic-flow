module DynamicFlow
  module Configuration

    mattr_accessor :document_form_class
    @@document_form_class = 'Document::Form'

    mattr_accessor :instance_class
    @@instance_class = 'DynamicFlow::Instance'

    mattr_accessor :user_class
    @@user_class = 'User'

    mattr_accessor :entry_class
    @@entry_class = "DynamicFlow::Entry"


    mattr_accessor :group_classes
    @@group_classes = {}

    mattr_accessor :queue_name
    @@queue_name = 'dynamic_flow_callbacks'

    mattr_accessor :instance_callbacks
    @@instance_callbacks = {
      created: { workers: {}, proc: nil },
      activated: { workers: {}, proc: nil },
      activation_failed: { workers: {}, proc: nil },
      suspended: { workers: {}, proc: nil },
      canceled: { workers: {}, proc: nil },
      finished: { workers: {}, proc: nil },
      finish_failed: {workers: {}, proc: nil}
    }

    mattr_accessor :transition_callbacks
    @@transition_callbacks = {
      :enabled => { workers: {"Default" => "DynamicFlow::Callbacks::TranisitionEnabled"}, proc: nil },
      :fired => { workers: {"Default" => "DynamicFlow::Callbacks::TranisitionFired"}, proc: nil },
      :fire_failed => { workers: {"Default" => "DynamicFlow::Callbacks::TranisitionFiredFailed"}, proc: nil },
      :task_enabled => { workers: {"Default" => "DynamicFlow::Callbacks::TaskEnabled"}, proc: nil },
      :task_assigned => { workers: {"Default" => "DynamicFlow::Callbacks::TaskEnabled"}, proc: nil },
      :task_unassigned => { workers: { "Default" => "DynamicFlow::Callbacks::TaskUnassigned"}, proc: nil },
      :task_started => { workers: {"Default" => "DynamicFlow::Callbacks::TaskStarted"}, proc: nil },
      :task_canceled => { workers: {"Default" => "DynamicFlow::Callbacks::TaskCanceled"}, proc: nil },
      :task_overriden => { workers: {"Default" => "DynamicFlow::Callbacks::TaskOverriden"}, proc: nil },
      :task_finished => { workers: { "Default" => "DynamicFlow::Callbacks::TaskFinished"}, proc: nil },
      :default_task_assignees => { workers: { "Default" => "DynamicFlow::Callbacks::DefaultTaskAssignees" }, proc: [] },
    }

    def setup &block
      yield(self)
    end

    def document_form_class_constant
      @@document_form_class.try :constantize
    end

    def instance_class_constant
      @@instance_class.try :constantize
    end

    def user_class_constant
      @@user_class.try :constantize
    end

    def entry_class_constant
      @@entry_class
    end

    def group_classes
      @@group_classes
    end

    def perform_instance_callback callback_name:, class_name: nil, payload: {}, delayed: true
      perform_callback :instance_callbacks, callback_name, class_name, payload, delayed
    end

    def perform_transition_callback callback_name:, class_name: nil, payload: {}, delayed: true
      perform_callback :transition_callbacks, callback_name, class_name, payload, delayed
    end

    def callback_for att, key, &block
      return unless send(att).keys.include?(key.to_sym)
      send(att)[key][:proc] = block
    end

    def perform_callback att, callback_name, class_name, payload, delayed
      return unless callback = send(att)[callback_name.to_sym]
      event_name = if att.to_sym == :instance_callbacks
        "instance_#{callback_name}"
      else
        "transition_#{callback_name}"
      end
      notification.instrument( type: event_name, event: payload)
      if callback[:workers].values.include?(class_name)
        res = if delayed
          class_name.constantize.perform_later(payload)
        else
          class_name.constantize.new(payload).perform_now
        end
        res
      else
        run_inline_callback att, callback_name, payload
      end
    end

    def run_inline_callback att, callback_name, payload
      return unless callback = send(att)[callback_name.to_sym]
      proc = callback[:proc]
      if(proc.is_a?(Proc))
        proc.call(payload)
      else
        proc
      end
    end

    def notification
      @@notification ||= Notification
    end

    @@transition_callbacks.keys.each do |key|
      define_method "transition_#{key}" do |&block|
        callback_for :transition_callbacks, key, &block
      end
    end

    @@instance_callbacks.keys.each do |key|
      define_method "instance_#{key}" do |&block|
        callback_for :instance_callbacks, key, &block
      end
    end

  end
end