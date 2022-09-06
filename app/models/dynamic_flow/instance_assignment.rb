module DynamicFlow
  class InstanceAssignment < ApplicationRecord

    belongs_to :instance
    belongs_to :transition
    belongs_to :actor

  end
end