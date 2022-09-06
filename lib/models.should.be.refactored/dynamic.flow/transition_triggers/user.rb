module DynamicFlow
  module TransitionTriggers
    class User < DynamicFlow::TransitionTrigger

      belongs_to :form, optional: true, polymorphic: true

    end
  end
end
