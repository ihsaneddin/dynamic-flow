module DynamicFlow
  module Callbacks
    class FireTransitionCallback < ApplicationJob
      queue_as DynamicFlow.queue_name

      def perform(*args)
        $stdout.puts(args.inspect)
      end
    end
  end
end
