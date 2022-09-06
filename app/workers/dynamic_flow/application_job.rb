module DynamicFlow
  class ApplicationJob < ActiveJob::Base

    attr_accessor :id
    class_attribute :model

    def perform(id, action, *args)
      self.id = id
      send(action, *args)
    end

    protected

    def resource &block
      if model
        @resource ||= model.find_by_id(self.id)
        if block_given? && @resource
          yield(@resource)
        end
      end
    end

    def model
      self.class.model
    end

  end
end
