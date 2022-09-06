module DynamicFlow
  module Callbacks
    class TaskAssigned < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(task_id: , actor_id: nil, user_id: nil)
        $stdout.puts(task_id)
        $stdout.puts(actor_id)
        $stdout.puts(user_id)
      end

    end
  end
end
