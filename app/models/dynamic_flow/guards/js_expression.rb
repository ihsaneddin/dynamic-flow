module DynamicFlow
  module Guards
    class JsExpression < DynamicFlow::Guard

      alias_attribute :value, :expression

      validates :value, presence: true
      validates :expression, presence: true

      def check_expression entry, task
        # 1000ms, 200mb
        context = MiniRacer::Context.new(timeout: 1000, max_memory: 200_000_000)
        context.eval("let task = #{task.to_json};")
        context.eval("let entry = #{entry.payload.to_json};")
        result = context.eval(expression)
        ActiveModel::Type::Boolean.new.cast(result)
      rescue => e
        DynamicFlow.raise_exception type: :javascript_expression, message: I18n.t("dynamic_flow.expression.javascript.error", e: e.message)
      end

      def pass? entry, task
        check_expression task
      end

    end
  end
end