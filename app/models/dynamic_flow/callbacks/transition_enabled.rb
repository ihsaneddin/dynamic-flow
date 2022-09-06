module DynamicFlow
  module Callbacks
    class TransitionEnabled < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(transition_id:, instance_id:)
        $stdout.puts(transition_id)
        $stdout.puts(instance_id)
      end

    end
  end
end
