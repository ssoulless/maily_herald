module MailyHerald
  class Dispatch < ActiveRecord::Base
    belongs_to  :list,          class_name: "MailyHerald::List"

    validates   :list,          presence: true
    validates   :state,         presence: true, inclusion: {in: [:enabled, :disabled, :archived]}
    validate do |dispatch|
      dispatch.errors.add(:base, "Can't change this dispatch because it is locked.") if dispatch.locked?
    end
    before_destroy do |dispatch|
      if dispatch.locked?
        dispatch.errors.add(:base, "Can't destroy this dispatch because it is locked.") 
        false
      end
    end

    delegate :subscription_for, to: :list

    scope       :enabled,       lambda { where(state: :enabled) }
    scope       :disabled,      lambda { where(state: :disabled) }
    scope       :archived,      lambda { where(state: :archived) }
    scope       :not_archived,  lambda { where("state != (?)", :archived) }

    scope       :sequence,      lambda { where(type: Sequence) }
    scope       :one_time_mailing, lambda { where(type: OneTimeMailing) }
    scope       :periodical_mailing, lambda { where(type: PeriodicalMailing) }

    def state
      read_attribute(:state).to_sym
    end

    def enabled?
      self.state == :enabled
    end
    def disabled?
      self.state == :disabled
    end
    def archived?
      self.state == :archived
    end

    def enable!
      update_attribute(:state, "enabled")
    end
    def disable!
      update_attribute(:state, "disabled")
    end
    def archive!
      update_attribute(:state, "archived")
    end

    def enable
      write_attribute(:state, "enabled")
    end
    def disable
      write_attribute(:state, "disabled")
    end
    def archive
      write_attribute(:state, "archived")
    end

    def list= l
      l = MailyHerald::List.find_by_name(l.to_s) if l.is_a?(String) || l.is_a?(Symbol)
      super(l)
    end

    def processable? entity
      self.enabled? && (self.override_subscription? || self.list.subscribed?(entity)) && self.list.context.scope.exists?(entity)
    end

    def locked?
      MailyHerald.dispatch_locked?(self.name)
    end

  end
end
