module DynamicFlow
  class Actor < ApplicationRecord
    belongs_to :context, polymorphic: true
    has_many :transition_static_assignments
    has_many :task_assignments
  end
end