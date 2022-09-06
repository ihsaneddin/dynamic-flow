require "dynamic_flow/version"
require "dynamic_flow/engine"
require 'dynamic_flow/configuration'
require 'dynamic_flow/errors'
require 'dynamic_flow/notification'
require 'dynamic_flow/dsl/workflow'

require 'mini_racer'
require "rgl/adjacency"
require "rgl/dijkstra"
require "rgl/topsort"
require "rgl/traversal"
require "rgl/path"
require 'script_core'

module DynamicFlow
  extend Configuration
  extend Errors

  def self.workflow
    DynamicFlow::DSL::Workflow
  end

end
