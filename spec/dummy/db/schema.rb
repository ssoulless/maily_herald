# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130723074347) do

  create_table "maily_herald_delivery_logs", :force => true do |t|
    t.datetime "delivered_at"
    t.integer  "entity_id",    :null => false
    t.string   "entity_type",  :null => false
    t.integer  "mailing_id"
  end

  create_table "maily_herald_mailings", :force => true do |t|
    t.string   "type",                                  :null => false
    t.integer  "sequence_id"
    t.string   "context_name"
    t.text     "conditions"
    t.string   "trigger",        :default => "manual",  :null => false
    t.string   "mailer_name",    :default => "generic", :null => false
    t.string   "name",                                  :null => false
    t.string   "title",                                 :null => false
    t.string   "from"
    t.text     "template",                              :null => false
    t.integer  "relative_delay"
    t.datetime "start"
    t.text     "start_var"
    t.integer  "period"
    t.boolean  "enabled",        :default => false
    t.integer  "position",       :default => 0,         :null => false
    t.boolean  "autosubscribe",  :default => true
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
  end

  add_index "maily_herald_mailings", ["context_name"], :name => "index_maily_herald_mailings_on_context_name"
  add_index "maily_herald_mailings", ["name"], :name => "index_maily_herald_mailings_on_name", :unique => true
  add_index "maily_herald_mailings", ["trigger"], :name => "index_maily_herald_mailings_on_trigger"

  create_table "maily_herald_sequences", :force => true do |t|
    t.string   "context_name",                     :null => false
    t.string   "name",                             :null => false
    t.datetime "start"
    t.text     "start_var"
    t.boolean  "enabled",       :default => false
    t.boolean  "autosubscribe", :default => true
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
  end

  add_index "maily_herald_sequences", ["context_name"], :name => "index_maily_herald_sequences_on_context_name"

  create_table "maily_herald_subscriptions", :force => true do |t|
    t.string   "type",                           :null => false
    t.integer  "entity_id",                      :null => false
    t.string   "entity_type",                    :null => false
    t.integer  "mailing_id"
    t.integer  "sequence_id"
    t.string   "token",                          :null => false
    t.text     "settings"
    t.text     "data"
    t.boolean  "active",       :default => true
    t.datetime "delivered_at"
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
  end

  add_index "maily_herald_subscriptions", ["type", "entity_id", "entity_type", "mailing_id", "sequence_id"], :name => "index_maliy_herald_subscriptions_unique", :unique => true

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.boolean  "weekly_notifications", :default => true
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
  end

end
