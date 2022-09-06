module DynamicFlow
  module Guards
    class JsExpression < ApplicationRecord

      alias_attribute :value, :query

      validates :value, presence: true
      validates :expression, presence: true

      def check_expression entry, task
        # 1000ms, 200mb
        context = MiniRacer::Context.new(timeout: 1000, max_memory: 200_000_000)
        context.eval("let task = #{task.to_json};")
        context.eval("let entry = #{entry.to_json};")
        result = context.eval(expression)
        ActiveModel::Type::Boolean.new.cast(result)
      end

      def pass? entry, task
        check_expression task
      end

    end
  end
end