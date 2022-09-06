module DynamicFlow
  module Errors
    class Exception < StandardError
      attr_reader :event

      def initialize msg, event= :error
        @event = event
        super msg
      end

    end
    class RubyExpressionError < Exception; end
    class JavascriptExpressionError < Exception; end
    class InstanceTransitionError < Exception; end
    class TransitionError < Exception; end
    class TaskError < Exception; end
    class GeneralError < Exception; end

    def raise_exception type: ,message: "", event: nil
      raise exceptions(type).new(message, event)
    end

    def raise_exception! type:, en:, event: nil
      raise exceptions(type).new(I18n.t(en), event)
    end

    def exceptions type
      case type.to_sym
      when :ruby_expression
        RubyExpressionError
      when :javascript_expression
        JavascriptExpressionError
      when :instance_transition
        InstanceTransitionError
      when :transition
        TransitionError
      when :task
        TaskError
      else
        GeneralError
      end
    end

    def delegate_exception e
      case e
      when AASM::InvalidTransition
        case e.object
        when DynamicFlow::Task
          raise_exception type: :task, message: I18n.t("dynamic_flow.task.transition.errors.#{e.failures[0] || 'general'}"), event: e.event_name
        when DynamicFlow::Instance
          raise_exception type: :instance, message: I18n.t("dynamic_flow.task.transition.errors.#{e.failures[0] || 'general'}"), event: e.event_name
        end
      else
        raise e
      end
    end

  end
end
