module DynamicFlow
  class WorkflowValidator < ActiveModel::Validator

    class IntegrityValidation

      attr_accessor :workflow, :start, :end, :normals, :rgl, :transitions, :places
      attr_accessor :messages

      def initialize record
        self.workflow = record
        self.start = workflow.places.start
        self.end = workflow.places.end
        self.places = workflow.places
        self.normals = workflow.places.normal
        self.rgl = workflow.to_rgl
        self.transitions = workflow.transitions
        self.messages = []
      end

      def validate!
        self.must_have_start
        self.must_have_end
        self.must_have_one_start_only
        self.must_have_one_end_only
        self.must_not_have_unconnected_transition
        if self.messages.present?
          workflow.update_columns(is_valid: false, message: messages.join("\n"))
        else
          workflow.update_columns(is_valid: true, message: nil)
        end
        self.messages.blank?
      end

      def must_have_start
        messages << I18n.t("dynamic_flow.workflow.invalid_message.start_is_missing") if self.start.blank?
      end

      def must_have_end
        messages << I18n.t("dynamic_flow.workflow.invalid_message.end_is_missing") if self.end.blank?
      end

      def must_have_one_start_only
        messages << I18n.t("dynamic_flow.workflow.invalid_message.only_one_start") if self.start.count > 1
      end

      def must_have_one_end_only
        messages << I18n.t("dynamic_flow.workflow.invalid_message.only_one_end") if self.end.count > 1
      end

      def must_not_have_unconnected_transition
        messages << I18n.t("dynamic_flow.workflow.invalid_message.invalid_discrete_transition") if transitions.any? { |t| !t.arcs.in.exists? }
      end

      def places_should_be_connected
        _start = self.start.first
        _end = self.end.first
        if _start && _end
          places.each do |p|
            messages << I18n.t("dynamic_flow.workflow.invalid_message.unreachable", p1: _start.name, p2: p.name) unless rgl.path?(_start.to_gid.to_s, p.to_gid.to_s)
            messages << I18n.t("dynamic_flow.workflow.invalid_message.unreachable", p1: p.name, p2: _end) unless rgl.path?(p.to_gid.to_s, _end.to_gid.to_s)
          end
          transitions.each do |t|
            messages << I18n.t("dynamic_flow.workflow.invalid_message.transition_unreachable", t1: _start.name, t2: t.name) unless rgl.path?(_start.to_gid.to_s, t.to_gid.to_s)
            messages << I18n.t("dynamic_flow.workflow.invalid_message.transition_unreachable", t1: t.name, t2: _end.name) unless rgl.path?(t.to_gid.to_s, _end.to_gid.to_s)
          end
        end
      end

      ### need simulation tool
      def has_deadlock?
      end

      def has_dead_transition?
      end

      def can_not_reach_end?
      end
      ####

    end

  end
end