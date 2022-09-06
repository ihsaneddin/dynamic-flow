module DynamicFlow
  module TransitionTriggers
    class Time < DynamicFlow::TransitionTrigger

      class Config < DynamicFlow::TransitionTrigger::Config
        attribute :delay_in_seconds, :integer, default: 1
        attribute :trigger_time, :datetime
        validates :delay_in_seconds,
                  numericality: {
                    only_integer: true,
                    greater_than_or_equal_to: 1
                  }
      end

      serialize :configuration, Config

    end
  end
end
