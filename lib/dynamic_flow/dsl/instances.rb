module DynamicFlow
  module DSL
    module Instances

      def new(workflow:, target: nil, started_by: nil)
        instance = workflow.instances.create!(targetable: target, started_by_task: started_by, state: :created)
      end

      def add_manual_assignment(instance, transition, actor)
        instance.instance_assignments.find_or_create_by!(transition: transition, actor: actor)
      end

      def add_token(instance, place)
        instance.tokens.create!(workflow: instance.workflow, place: place, state: :free)
      end

      def enable_transition instance
        DynamicFlow::ApplicationRecord.transaction do
          instance.tasks.enabled.each do |task|
            unless instance.can_fire?(task.transition)
              task.update!(state: :overridden, overridden_at: Time.zone.now)
            end
          end
          instance.workflow.transitions.each do |transition|
            next unless instance.can_fire?(transition) && !transition.tasks.where(instance: instance, state: %i[enabled started]).exists?
            if(transition.transition_trigger.is_a?(DynamicFlow::TransitionTriggers::Time))
              trigger_time = Time.zone.now + transition.transition_trigger.config.delay_in_seconds.seconds
              task = instance.tasks.create!(workflow: instance.workflow, transition: transition, state: :enabled, trigger_time: trigger_time)

            end
          end
        end
      end

      def cancel instance
        unless instance.suspended? || instance.active?
          raise DynamicFlow::InstanceTransitionError, I18n.t("dynamic_flow.instance.transition.errors.can_not_be_canceled")
        end
        instance.canceled!
      end

      def clear_manual_assignments instance, transition
        instance.instance_assignments.where(transition: transition).find_each(&:destroy)
      end

      def consume_token instance, place, locked_task=nil
        DynamicFlow::ApplicationRecord.transaction do
          if locked_task
            instance.tokens.where(place: place, state: :locked, locked_task_id: locked_taks.id).update(consumed_at: Time.zone.now, state: :consumed)
          else
            instance.tokens.where(id: instance.tokens.where(place: place, state: :free).first&.id).update(consumed_at: Time.zone.now, state: :consumed)
          end
        end
      end

    end
  end
end