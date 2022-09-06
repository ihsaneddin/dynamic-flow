require_relative "lib/dynamic_flow/version"

Gem::Specification.new do |spec|
  spec.name        = "dynamic_flow"
  spec.version     = DynamicFlow::VERSION
  spec.authors     = [""]
  spec.email       = ["ihsaneddin@gmail.com"]
  spec.homepage    = "https://github.com/ihsaneddin"
  spec.summary     = "Summary of DynamicFlow."
  spec.description = "Description of DynamicFlow."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.3", ">= 6.1.3.1"
  spec.add_dependency "acts_as_list", "~> 1.0"
  spec.add_dependency "ancestry", "~> 4.0"
  spec.add_dependency "rgl", "~> 0.5"
  spec.add_dependency 'document', '~> 1.0'
  spec.add_dependency 'script_core'
  spec.add_dependency "mini_racer"
end
