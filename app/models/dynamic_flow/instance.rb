module DynamicFlow
  class Instance < ApplicationRecord
    belongs_to :workflow
    belongs_to :targetable, optional: true, polymorphic: true
    belongs_to :started_by_task, optional: true, class_name: "DynamicFlow::Task"
    has_many :tasks
    has_many :tokens
    has_many :instance_assignments
    has_many :actors, through: :instance_assignments, source: "actor"

    include AASM

    aasm column: :state do

      state :created, initial: true
      state :active
      state :suspended
      state :canceled
      state :finished

      event :activate do
        after do
          after_activation_callback
        end
        transitions from: [:created, :suspended, :canceled], to: :active, guards: [:activation_guard]
      end
      event :suspend do
        transitions from: [:active], to: :suspended
      end
      event :cancel do
        transitions from: [:active, :suspended], to: :canceled
      end
      event :resume do
        transitions from: [:canceled, :suspended], to: :active
      end
      event :finish do
        after do
          after_finish_callback
        end
        transitions from: [:active], to: :finished, guards: [:finish_guard]
      end
    end

    ### START of aasm callbacks
    def activation_guard
      is_workflow_valid?
    end

    def after_activation_callback
      create_token workflow.places.start.first
      enable_transitions!
      perform_callback callback_name: :activated, payload: {instance_id: id}
    end

    def finish_guard
      !is_miscontructed?
    end

    def after_finish_callback
      consume_token end_place
      if started_by_task
        started_by_task.finish!
      end
    end
    ### END of aasm callbacks

    ### START of token methods
    def create_token place
      tokens.create! place: place
    end

    def release_token task
      DynamicFlow::Token.where(locked_task_id: task.id).locked.each do |token|
        create_token token.place
        token.cancel!
      end
    end

    def consume_token place, locked_task=nil
      if locked_task
        tokens.where(place: place, locked_task_id: locked_task.id).locked.find_each do |token|
          token.consume!
        end
      else
        tokens.where(id: tokens.where(place: place).free.first&.id ).find_each do |token|
          token.consume!
        end
      end
    end

    def lock_token place, task
      tokens.free.where(place: place).limit(1).each do |token|
        token.to_lock! task
      end
    end
    ### END of token methods

    ### START of core methods
    attr_accessor :_misconstructed

    def end_place
      @end_place ||= workflow.places.end.first
    end

    def is_at_end_place?
      DynamicFlow::ApplicationRecord.uncached {  tokens.where(place: end_place).count } > 0
    end

    def is_ready_to_finish?
      tokens.where(place: end_place).where(state: %w[locked]).count > 0
    end

    def free_and_locked_token_count_of_end_place
      tokens.where(place: end_place).where(state: %w[free locked]).count
    end

    def is_miscontructed?
      if is_at_end_place?
        self._misconstructed = free_and_locked_token_count_of_end_place > 1
      end
      self._misconstructed
    end

    def is_workflow_valid?
      workflow.is_valid
    end

    def identification_name
      "Instance->#{id}"
    end

    def enable_transitions!
      workflow.transitions.each do |transition|
        transition.enable! self
      end
    end

    def can_fire?(transition)
      transition.can_be_fired? self
    end

    def add_manual_assignment(transition, actor)
      instance_assignments.find_or_create_by!(transition: transition, actor: actor)
    end

    def clear_task_assignments permanent= true
      transaction do
        clear_manual_assignments if permanent
        instance_assignments.delete_all
      end
    end

    def clear_manual_assignments transition
      instance_assignments.where(transition: transition).find_each &:destroy
    end

    def perform_callback callback_name:, payload: {}
      callback = config.callbacks.filter{|c| c.name == callback_name.to_s }.first
      DynamicFlow.perform_instance_callback(callback_name: callback_name.to_sym, payload: payload, class_name:callback.try(:class_name), delayed: callback.try(:delayed) )
    end

    ### END of core methods

    class Config < Document::FieldOptions

      embeds_many :handlers, class_name: "DynamicFlow::Instance::Handler"
      accepts_nested_attributes_for :handlers, reject_if: :all_blank, allow_destroy: true

      alias_method :callbacks=, :handlers_attributes=
      alias_method :callbacks, :handlers

    end

    class Handler < Document::FieldOptions

      attribute :name, :string, default: ""
      attribute :class_name, :string, default: ""
      attribute :delayed, :boolean, default: true

      validates :name, presence: true, inclusion: { in: DynamicFlow.instance_callbacks.keys.map{|c| c.to_s}, allow_blank: true }
      validates :class_name, presence: true

    end

    serialize :configuration, Config
    alias_attribute :config, :configuration

  end
end
