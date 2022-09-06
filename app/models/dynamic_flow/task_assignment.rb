module DynamicFlow
  class TaskAssignment < ApplicationRecord
    belongs_to :actor
    belongs_to :task
  end
end
