module DynamicFlow
  module Callbacks
    class TransitionFired < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(transition_id:, instance_id:, task_id:)
        $stdout.puts(transition_id)
        $stdout.puts(instance_id)
        $stdout.puts(task_id)
      end

    end
  end
end
