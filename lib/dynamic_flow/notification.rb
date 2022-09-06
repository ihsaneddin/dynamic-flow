module DynamicFlow
  module Notification

    class << self
      delegate :configure, :instrument, :subscribe, :unsubscribe, :listening?, to: :delegator

      def delegator
        @delegator ||= Delegator.new
      end

    end

    class Delegator
      attr_reader :backend

      def initialize
        @backend = ActiveSupport::Notifications
      end

      def configure(&block)
        raise ArgumentError, "must provide a block" unless block
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end

      def subscribe(name, callable = nil, &block)
        callable ||= block
        backend.subscribe to_regexp(name), NotificationAdapter.new(callable)
      end

      def all(callable = nil, &block)
        callable ||= block
        subscribe nil, callable
      end

      def unsubscribe(name)
        backend.unsubscribe name
      end

      def instrument(event:, type:)
        backend.instrument name_with_namespace(type), event
      end

      def listening?(type)
        backend.notifier.listening? name_with_namespace(type)
      end

      class NotificationAdapter
        def initialize(subscriber)
          @subscriber = subscriber
        end

        def call(*args)
          payload = args.last
          @subscriber.call(payload)
        end
      end

      private

      def to_regexp(name)
        %r{^#{Regexp.escape name_with_namespace(name)}}
      end

      def name_with_namespace(name, delimiter: ".")
        [:dynamic_flow, name].join(delimiter)
      end
    end
  end
end