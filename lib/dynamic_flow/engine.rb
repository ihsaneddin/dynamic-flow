module DynamicFlow
  class Engine < ::Rails::Engine
    isolate_namespace DynamicFlow
    initializer "dynamic_flow.load_default_i18n" do
      ActiveSupport.on_load(:i18n) do
        I18n.load_path << File.expand_path("locale/en.yml", __dir__)
      end
    end
  end
end
