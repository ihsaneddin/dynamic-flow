module DynamicFlow
  class Arc < ApplicationRecord
    belongs_to :workflow, touch: true
    belongs_to :transition
    belongs_to :place

    has_many :guards, dependent: :destroy

    scope :with_guards, -> { where("guards_count > 0") }
    scope :without_guards, -> { where(guards_count: 0) }
    scope :guards_count_desc, -> { order("guards_count DESC") }

    enum direction: {
      in: 0,
      out: 1
    }

    def name
      if in?
        [place&.name, transition&.name].join(" -> ")
      else
        [transition&.name, place&.name].join(" -> ")
      end
    end
  end
end
