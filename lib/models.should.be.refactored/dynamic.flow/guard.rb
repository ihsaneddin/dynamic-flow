module DynamicFlow
  class Guard < ApplicationRecord

    belongs_to :form, optional: true
    belongs_to :workflow
    belongs_to :arc, touch: true, counter_cache: true

    before_validation do
      self.workflow = arc.workflow
    end

    def pass? entry, task
      true
    end

  end
end
