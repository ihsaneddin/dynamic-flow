module DynamicFlow
  class Place < ApplicationRecord

    TYPES = ["DynamicFlow::Places::Start", "DynamicFlow::Places::Normal", "DynamicFlow::Places::End"]

    belongs_to :workflow, touch: true
    has_many :arcs
    has_many :tokens

    scope :start, -> { where(type: "DynamicFlow::Places::Start") }
    scope :normal, -> { where(type: "DynamicFlow::Places::Normal") }
    scope :end, -> { where(type: "DynamicFlow::Places::End") }

    scope :order_by_types, -> (ord = 'asc') {
      order_by = ['CASE']
      TYPES.each_with_index do |type, index|
        order_by << "WHEN dynamic_flow_places.type = '#{type}' THEN #{index}"
      end
      order_by << 'END'
      order(Arel.sql("#{order_by.join(' ')} #{ord}"))
    }

    def graph_id
      "#{name}/#{id}"
    end


  end
end