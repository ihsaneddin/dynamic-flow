module DynamicFlow
  module Callbacks
    class DefaultTaskAssignees < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(task_id: nil)
        []
      end

    end
  end
end
