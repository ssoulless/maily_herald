require 'spec_helper'

describe MailyHerald::Sequence do
  before(:each) do
    @sequence = MailyHerald.sequence(:newsletters)
    @sequence.should be_a MailyHerald::Sequence
    @sequence.should_not be_a_new_record
  end

  after(:all) do
    Timecop.return
  end

  describe "Validations" do
    it {should validate_presence_of(:context_name)}
    it {should validate_presence_of(:name)}
  end


  describe "Associations" do
    it {should have_many(:subscriptions)}
    it {should have_many(:mailings)}

    it "should have valid 'through' associations" do
      @sequence.mailings.length.should_not be_zero
    end
  end

  describe "Subscriptions" do
    before(:each) do
      @entity = FactoryGirl.create :user
    end

    it "should find or initialize sequence subscription" do
      subscription = @sequence.subscription_for @entity
      subscription.should be_valid
      subscription.should_not be_a_new_record
    end
  end

  describe "markup evaluation" do
    before(:each) do
      @entity = FactoryGirl.create :user
    end

    after(:each) do
      @sequence.update_attribute(:start, nil)
    end

    it "should parse start_var" do
      @entity.should be_a(User)
      subscription = @sequence.subscription_for @entity
      subscription.next_delivery_time.should be_a(Time)
    end

    it "should use absolute start date if possible" do
      @entity.should be_a(User)
      time = @entity.created_at + rand(100).days + rand(24).hours + rand(60).minutes
      @sequence.update_attribute(:start, time)
      @sequence.start.should be_a(Time)
      subscription = @sequence.subscription_for @entity
      subscription.next_delivery_time.should be_a(Time)
      subscription.next_delivery_time.should eq(time + @sequence.mailings.first.relative_delay)
    end
  end

  describe "Scheduled Delivery" do
    before(:each) do
      @entity = FactoryGirl.create :user
    end

    after(:each) do
      @sequence.mailings[1].update_attribute(:enabled, true)
    end

    it "should deliver mailings with delays" do
      @sequence.mailings.length.should eq(3)
      @sequence.start.should be_nil

      subscription = @sequence.subscription_for(@entity)
      subscription.delivered_mailings.length.should eq(0)
      subscription.pending_mailings.length.should eq(@sequence.mailings.length)
      subscription.next_mailing.relative_delay.should_not eq(0)
      subscription.next_delivery_time.should eq(@entity.created_at + @sequence.mailings.first.relative_delay)

      Timecop.freeze @entity.created_at

      @sequence.run

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(1)
      MailyHerald::DeliveryLog.count.should eq(0)

      Timecop.freeze @entity.created_at + @sequence.mailings.first.relative_delay + 10.minutes

      @sequence.run

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(1)
      MailyHerald::DeliveryLog.count.should eq(1)

      subscription = @sequence.subscription_for(@entity)
      subscription.should_not be_nil
      subscription.should_not be_a_new_record
      subscription.entity.should eq(@entity)

      subscription.delivered_mailings.length.should eq(1)
      subscription.pending_mailings.length.should eq(@sequence.mailings.length - 1)
      
      subscription.last_delivered_mailing.should eq @sequence.mailings.first
      log = subscription.mailing_log_for(@sequence.mailings.first)
      log.delivered_at.to_i.should eq (@entity.created_at + 1.hour + 10.minutes).to_i

      Timecop.freeze @entity.created_at + 2.hour + 10.minutes

      @sequence.run

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(1)
      MailyHerald::DeliveryLog.count.should eq(1)

      Timecop.freeze @entity.created_at + 3.hour + 10.minutes

      @sequence.run

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(1)
      MailyHerald::DeliveryLog.count.should eq(2)

      subscription = @sequence.subscription_for(@entity)
      log = subscription.mailing_log_for(@sequence.mailings.first)
      log.should be_a(MailyHerald::DeliveryLog)
      log.entity.should eq(@entity)

      log = subscription.mailing_log_for(@sequence.mailings[1])
      log.should be_a(MailyHerald::DeliveryLog)
      log.entity.should eq(@entity)
    end

    it "should skip disabled mailings and go on with delivery" do
      @sequence.mailings.length.should eq(3)
      @sequence.start.should be_nil
      @sequence.should be_enabled

      subscription = @sequence.subscription_for(@entity)

      @sequence.mailings[0].should be_enabled
      @sequence.mailings[1].should be_enabled
      @sequence.mailings[2].should be_enabled

      @sequence.mailings[1].update_attribute(:enabled, false)
      @sequence.mailings[1].should_not be_enabled

      subscription.pending_mailings.first.should eq(@sequence.mailings.first)
      subscription.pending_mailings.first.should be_enabled

      Timecop.freeze @entity.created_at + subscription.pending_mailings.first.relative_delay

      @sequence.run

      MailyHerald::DeliveryLog.count.should eq(1)
      subscription.delivered_mailings.length.should eq(1)

      subscription.pending_mailings.should_not include(@sequence.mailings[1])
      subscription.next_mailing.should eq(@sequence.mailings[2])

      Timecop.freeze @entity.created_at + @sequence.mailings[0].relative_delay + @sequence.mailings[2].relative_delay

      @sequence.run

      MailyHerald::DeliveryLog.count.should eq(2)
      subscription.pending_mailings.should be_empty
    end
  end

  describe "Error handling" do
    before(:each) do
      @old_start_var = @sequence.start_var
      @sequence.update_attribute(:start_var, "")
      @entity = FactoryGirl.create :user
    end

    after(:each) do
      @sequence.update_attribute(:start_var, @old_start_var)
      @sequence.update_attribute(:start, nil)
    end

    it "should handle start_var parsing errors or nil start time" do
      @sequence.start.should be_nil
      @sequence.start_var.should eq("")
      subscription = @sequence.subscription_for @entity
      subscription.last_delivery_time.should be_nil
      subscription.next_delivery_time.should be_nil

      Timecop.freeze @entity.created_at
      @sequence.run

      subscription = @sequence.subscription_for @entity
      subscription.last_delivery_time.should be_nil
      subscription.next_delivery_time.should be_nil
    end

    it "should allow to set start date via text field" do
      datetime = "2013-01-01 10:11"

      @sequence.start.should be_nil
      @sequence.start_text = datetime
      @sequence.should be_valid
      @sequence.start.to_i.should eq(Time.zone.parse(datetime).to_i)
      @sequence.start_text.should eq(datetime)

      @sequence.start_text = ""
      @sequence.should be_valid
      @sequence.start.should be_nil
    end
  end

  describe "Autosubscribe" do
    before(:each) do
      @sequence.autosubscribe = false
      @sequence.should be_valid
      @sequence.save.should be_true
      @entity = FactoryGirl.create :user
    end

    it "should not create subscription without autosubscribe" do
      subscription = @sequence.subscription_for @entity

      subscription.should be_new_record

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(0)
      MailyHerald::DeliveryLog.count.should eq(0)

      Timecop.freeze @entity.created_at

      @sequence.run

      MailyHerald::MailingSubscription.count.should eq(0)
      MailyHerald::SequenceSubscription.count.should eq(0)
      MailyHerald::DeliveryLog.count.should eq(0)

      @sequence.autosubscribe = true
      @sequence.save
    end
  end

  describe "Subscription override" do
    before(:each) do
      @entity = FactoryGirl.create :user
    end

    after(:each) do
      @sequence.update_attribute(:override_subscription, false)
    end

    it "should be able to override subscription" do
      subscription = @sequence.subscription_for @entity

      subscription.should be_active

      next_delivery = subscription.next_delivery_time

      subscription.deactivate!
      subscription.should_not be_active

      subscription.last_delivery_time.should be_nil

      Timecop.freeze subscription.next_delivery_time

      @sequence.run

      subscription.last_delivery_time.should be_nil


      @sequence.update_attribute(:override_subscription, true)

      @sequence.run

      subscription.last_delivery_time.to_i.should eq(next_delivery.to_i)
    end
  end

end