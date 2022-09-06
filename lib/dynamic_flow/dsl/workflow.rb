require 'active_record/base'

module DynamicFlow
  module DSL
    class Workflow

      attr_reader :object
      attr_reader :callbacks
      attr_reader :attributes

      def initialize args
        @callbacks = {
          error: nil
        }
        @object = case args
          when Hash
           build args
          when DynamicFlow::Workflow
            args
          else
            find args
          end
      end

      def error &block
        @callbacks[:error] = Proc.new
      end

      protected

      def build attrs
        DynamicFlow::Workflow.create!(args)
      end

      def find args
        DynamicFlow::Workflow.find!(args)
      end

      def perform_callback key, *args
        if @callbacks[key].is_a? Proc
          instance_exec(*args, &@callbacks[key])
        else
          yield *args
        end
      end

      class << self

        def setup args
          workflow_dsl = self.new args

          if block_given?
            begin
              ActiveRecord::Base.transaction do
                workflow_dsl.instance_exec &Proc.new
              end
            rescue => e
              perform_callback :error, e do
                raise e
              end
            end
          end
        end

      end

      class Transition

        attr_reader :object

        def initialize workflow, args
          raise TypeError unless work.is_a? DynamicFlow::DSL::Workflow

        end

        def build
        end

        def find args
        end

      end

      class Place
      end

      class Arc
      end

    end
  end
end