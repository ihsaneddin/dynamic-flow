module DynamicFlow
  module Guards
    class Query < DynamicFlow::Guard

      serialize :query, Document::Concerns::VirtualModels::AdvancedSearch::Builder

      after_initialize do
        if respond_to? :query
          self.query ||= {}
        end
      end

      def check_expression entry, task
        vmodel = entry.form.to_virtual_model
        _query = vmodel.run_advanced_search query.clauses.map(&:as_json)
        _query = _query.where(id: entry.payload_id)
        _query.first ? true : false
      end

      def pass? entry, task
        check_expression entry, task
      end

    end
  end
end
