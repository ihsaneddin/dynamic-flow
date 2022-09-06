module DynamicFlow
  class Entry < ApplicationRecord
    belongs_to :form, optional: true, class_name: DynamicFlow.document_form_class
    belongs_to :user, class_name: DynamicFlow.user_class
    belongs_to :task

    serialize :payload, Hash

    after_initialize do
      self.payload = {} if payload.blank?
    end

    attr_accessor :payload_object

    def payload_id
      payload.deep_symbolize_keys[:id] if payload.is_a?(Hash)
    end

    def update_payload object
      self.payload_object = object
      unless object.errors.any?
        update payload: object.as_json.merge({"id": object._id.to_s})
      end
    end

    def get_payload_object
      form.to_virtual_model.find(payload_id)
    end

    def as_json *args
      if args.present?
        super
      else
        payload || {}
      end
    end

    def to_json *args
      if args.present?
       super
      else
        as_json.to_json
      end
    end

  end
end
