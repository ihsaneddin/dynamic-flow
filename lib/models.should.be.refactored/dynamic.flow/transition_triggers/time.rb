module DynamicFlow
  module TransitionTriggers
    class Time < DynamicFlow::TransitionTrigger

      class Config < DynamicFlow::TransitionTrigger::Config
        attribute :delay_in_seconds, :integer, default: 1
        attribute :trigger_time, :date_time
      end

    end
  end
end
