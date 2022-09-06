Rails.application.routes.draw do
  mount DynamicFlow::Engine => "/dynamic_flow"
end
