module DynamicFlow
  module Guards
    class RubyExpression < ApplicationRecord

      alias_attribute :value, :query

      validates :value, presence: true
      validates :expression, presence: true

      def check_expression entry, task
        result = DynamicFlow::ScriptEngine.run_inline expression, payload: { entry: entry, task: task }
        if result.errors.any?
          raise DynamicFlow::RubyExpressionError, I18n.t("dynamic_flow.expression.ruby,error", e: result.errors)
        end
        ActiveModel::Type::Boolean.new.cast(result.output)
      end

      def pass? entry, task
        check_expression task
      end

    end
  end
end
