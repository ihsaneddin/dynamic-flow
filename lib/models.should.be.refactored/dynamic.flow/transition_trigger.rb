module DynamicFlow
  class TransitionTrigger < ApplicationRecord

    belongs_to :transition, touch: true


    class Config < Document::FieldOptions

      attribute :notify_task_assignment_callback, :string, default: ""
      attribute :default_actors_assignment_callback, :string, default: ""
      attribute :task_assignment_empty_callback, :string, default: ""
      attribute :fire_transition_callback, :string, default: ""

      attribute :callback_when_task_enabled, :string, default: ""
      attribute :callback_when_fired, :string, default: ""
      attribute :callback_when_assigned, :string, default: ""
      attribute :callback_when_unassigned, :string, default: ""
      attribute :callback_when_task_created, :string, default: ""

    end

    serialize :config, Config
  end
end