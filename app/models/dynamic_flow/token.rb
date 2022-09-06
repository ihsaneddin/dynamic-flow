module DynamicFlow
  class Token < ApplicationRecord
    belongs_to :workflow
    belongs_to :instance
    belongs_to :place
    belongs_to :locked_task, class_name: "DynamicFlow::Task", optional: true

    before_validation do
      self.workflow ||= instance.try :workflow
    end

    include AASM

    aasm column: :state do

      state :free, initial: true
      state :locked
      state :canceled
      state :consumed

      event :to_lock do
        transitions from: [:free], to: :locked do
          guard do |task|
            task.is_a? DynamicFlow::Task
          end
          after do |task|
            update locked_task: task, locked_at: Time.zone.now
          end
        end
      end

      event :cancel do
        transitions from: :locked, to: :canceled do
          guard do |task|
            task.is_a? DynamicFlow::Task
          end
          after do |task|
            stamps :canceled_at
          end
        end
      end

      event :consume do
        transitions from: [:locked, :free], to: :consumed do
          after do
            stamps :consumed_at
          end
        end
      end

    end

    def stamps att
      update_column att, Time.zone.now
    end

  end
end
