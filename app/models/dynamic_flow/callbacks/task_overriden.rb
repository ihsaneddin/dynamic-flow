module DynamicFlow
  module Callbacks
    class TaskOverriden < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(task_id:)
        $stdout.puts(task_id)
      end

    end
  end
end
