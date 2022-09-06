module DynamicFlow
  module Callbacks
    class DefaultActorsAssignmentCallback < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(*args)
        []
      end
    end
  end
end
