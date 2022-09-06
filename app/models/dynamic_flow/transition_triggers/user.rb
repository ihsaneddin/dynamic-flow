module DynamicFlow
  module TransitionTriggers
    class User < DynamicFlow::TransitionTrigger

      belongs_to :form, class_name: DynamicFlow.document_form_class

    end
  end
end
