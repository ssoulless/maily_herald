module MailyHerald
  class Manager
    def self.handle_trigger type, entity
      mailings = Mailing.where(trigger: type)
      mailings.each do |mailing|
        mailing.deliver_to entity
      end
    end

    def self.deliver mailing, entity
      mailing = Mailing.find_by_name(mailing) if !mailing.is_a?(Mailing)
      entity = mailing.context.scope.find(entity) if entity.is_a?(Fixnum)

      mailing.deliver_to entity if mailing
    end

    def self.run_sequence seq
      seq = Sequence.find_by_name(seq) if !seq.is_a?(Sequence)

      seq.run if seq
    end

    def self.run_mailing mailing
      mailing = Mailing.find_by_name(mailing) if !mailing.is_a?(Mailing)

      mailing.run if mailing
    end

    def self.run_all
      PeriodicalMailing.all.each {|m| m.run}
      Sequence.all.each {|m| m.run}
    end

    def self.simulate period
      File.open("/tmp/maily_herlald_timetravel.lock", "w") {}
      time = Time.now
      end_time = time + period
      while time < end_time 
        Timecop.freeze(time)
        run_all
        time = time + 1.day
      end
      Timecop.return
      File.delete("/tmp/maily_herlald_timetravel.lock")
    end

    def self.job_enqueued?
      Sidekiq::Queue.new.detect{|j| j.klass == "MailyHerald::Async" } || 
        Sidekiq::Workers.new.detect{|w, msg| msg["payload"]["class"] == "MailyHerald::Async" } ||
        Sidekiq::RetrySet.new.detect{|j| j.klass = "MailyHerald::Async" }
    end
  end
end
