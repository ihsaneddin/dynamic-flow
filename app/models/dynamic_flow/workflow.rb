module DynamicFlow
  class Workflow < ApplicationRecord

    has_many :places, :dependent => :destroy
    has_one :start, class_name: "DynamicFlow::Places::Start", foreign_key: :workflow_id
    has_many :ends, class_name: "DynamicFlow::Places::End", foreign_key: :workflow_id
    has_many :transitions, :dependent => :destroy
    has_many :arcs, dependent: :destroy
    has_many :transition_static_assignments
    has_many :instances
    has_many :tasks
    has_many :tokens
    has_many :messages

    validates :name, presence: true
    after_save do
      verify_structure!
    end

    after_touch do
      verify_structure!
    end

    scope :valid, -> { where(is_valid: true) }

    def to_rgl
      graph = RGL::DirectedAdjacencyGraph.new
      places.order_by_types.each do |p|
        graph.add_vertex(p.to_gid.to_s)
      end

      transitions.each do |t|
        graph.add_vertex(t.to_gid.to_s)
      end

      arcs.order(direction: :desc).each do |arc|
        if arc.in?
          graph.add_edge(arc.place.to_gid.to_s, arc.transition.to_gid.to_s)
        else
          graph.add_edge(arc.transition.to_gid.to_s, arc.place.to_gid.to_s)
        end
      end

      graph
    end

    def verify_structure!
      DynamicFlow::WorkflowValidator::IntegrityValidation.new(self).validate!
    end

  end
end