# frozen_string_literal: true

class CreateAmazonSnsSubscription < ActiveRecord::Migration[5.1]
  def change
    create_table :amazon_sns_subscriptions do |t|
      t.integer :user_id, null: false
      t.string :device_token, null: false
      t.string :application_name, null: false
      t.string :platform, null: false
      t.string :endpoint_arn, null: false
      t.timestamps
    end

    add_index :amazon_sns_subscriptions, [:device_token], unique: true

  end
end
