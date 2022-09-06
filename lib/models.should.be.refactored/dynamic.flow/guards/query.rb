module DynamicFlow
  module Guards
    class Query < ApplicationRecord

      serialize :query, Document::Concerns::VirtualModels::AdvancedSearch::Builder

      after_initialize do
        if respond_to? :query
          self.query ||= {}
        end
      end

      def check_expression entry, task
        false
      end

      def pass? entry, task
        check_expression task
      end

    end
  end
end
