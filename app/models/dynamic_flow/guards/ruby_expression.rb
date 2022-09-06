module DynamicFlow
  module Guards
    class RubyExpression < DynamicFlow::Guard

      alias_attribute :expression, :query

      validates :expression, presence: true

      def check_expression entry, task
        result = DynamicFlow::ScriptEngine.run_inline expression, payload: { "entry": entry.as_json, "task": task.as_json }.as_json
        if result.errors.any?
          DynamicFlow.raise_exception type: :ruby_expression, message: I18n.t("dynamic_flow.expression.ruby.error", e: result.errors)
        end
        ActiveModel::Type::Boolean.new.cast(result.output)
      rescue => e
        DynamicFlow.raise_exception type: :ruby_expression, message: I18n.t("dynamic_flow.expression.ruby.error", e: e.message)
      end

      def pass? entry, task
        check_expression entry, task
      end

    end
  end
end
