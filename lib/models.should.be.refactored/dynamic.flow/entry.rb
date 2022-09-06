module DynamicFlow
  class Entry < ApplicationRecord
    belongs_to :form, optional: true
    belongs_to :user, class_name: DynamicFlow.user_class
    belongs_to :task

    after_initialize do
      self.payload = {} if payload.blank?
    end

    def update_payload! json
      update(payload: json)
    end
  end
end
