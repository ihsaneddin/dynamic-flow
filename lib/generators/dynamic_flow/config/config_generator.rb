module DynamicFlow
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      source_root File.join(__dir__, "templates")

      def generate_config
        copy_file "dynamic_flow.rb", "config/initializers/dynamic_flow.rb"
      end
    end
  end
end