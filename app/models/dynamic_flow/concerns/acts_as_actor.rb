module DynamicFlow
  module Concerns
    module ActsAsActor
      extend ActiveSupport::Concern

      included do
        has_one :actor, as: :context, class_name: "DynamicFlow::Actor"
      end

      module ClassMethods

        def acts_as_actor(opts = {name: :name, user: true} )
          has_many :users, class_name: self.name, foreign_key: :id if opts[:user]
          after_create do
            _name = opts[:name] || :name
            if opts[:name].is_a? Symbol
              _name = send(opts[:name])
            end
            create_actor(name: _name)
          end
        end

      end
    end
  end
end
