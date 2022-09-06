module DynamicFlow
  class TransitionTrigger < ApplicationRecord

    belongs_to :transition, touch: true
    alias_attribute :config, :configuration


    class Config < Document::FieldOptions

      embeds_many :handlers, class_name: "DynamicFlow::TransitionTrigger::Handler"
      accepts_nested_attributes_for :handlers, reject_if: :all_blank, allow_destroy: true

      # attribute :enabled, :string, default: ""
      # attribute :delay_enabled, :boolean, default: true
      # attribute :fired, :string, default: ""
      # attribute :fire_failed, :striing, default: ""

      # attribute :task_assigned, :string, default: ""
      # attribute :task_unassigned, :string, default: ""
      # attribute :task_enabled, :string, default: ""
      # attribute :task_started, :string, default: ""
      # attribute :task_canceled, :string, default: ""
      # attribute :task_overriden, :string, default: ""
      # attribute :task_finished, :string, default: ""
      # attribute :default_task_assignees, default: ""

      alias_method :callbacks=, :handlers_attributes=
      alias_method :callbacks, :handlers

    end

    class Handler < Document::FieldOptions

      attribute :name, :string, default: ""
      attribute :class_name, :string, default: ""
      attribute :delayed, :boolean, default: true

      validates :name, presence: true, inclusion: { in: DynamicFlow.transition_callbacks.keys.map{|c| c.to_s}, allow_blank: true }
      validates :class_name, presence: true

    end

    serialize :configuration, Config
  end
end