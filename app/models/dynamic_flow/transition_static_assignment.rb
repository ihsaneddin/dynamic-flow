module DynamicFlow
  class TransitionStaticAssignment < ApplicationRecord
    belongs_to :workflow
    belongs_to :transition
    belongs_to :actor

    validates :actor_id, uniqueness: { scope: %i[workflow_id transition_id] }

    before_validation do
      self.workflow_id = transition&.workflow_id
    end
  end
end