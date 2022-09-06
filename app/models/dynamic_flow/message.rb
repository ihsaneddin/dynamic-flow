module DynamicFlow
  class Message < ApplicationRecord

    CONTEXTS = {
      instance: %w[created activated activation_failed suspended canceled finished finish_failed],
      transition: %w[enabled fired fire_failed task_enabled task_assigned task_unassigned task_started task_canceled task_overriden task_finished ]
    }

    belongs_to :workflow
    belongs_to :context, polymorphic: true

    validates :event, presence: true, inclusion: { in: -> (object) { CONTEXT[object.context_type_short.to_sym] || [] }, allow_blank: true }
    validates :message, presence: true

    def context_type_short
      context_type.to_s.demodulize.underscore
    end

  end
end