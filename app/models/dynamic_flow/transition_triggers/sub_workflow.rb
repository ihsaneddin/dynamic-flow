module DynamicFlow
  module TransitionTriggers
    class SubWorkflow < DynamicFlow::TransitionTrigger

      belongs_to :sub_workflow, optional: true, class_name: "DynamicFlow::Workflow"

      class Config < DynamicFlow::TransitionTrigger::Config
        attribute :strict, :boolean, default: true
      end

      serialize :configuration, Config

    end
  end
end
