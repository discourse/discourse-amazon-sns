# frozen_string_literal: true

class RenameEnabledToStatusAndAddStatusChanged < ActiveRecord::Migration[6.0]
  def up
    add_column :amazon_sns_subscriptions, :status, :integer, default: 1, null: false
    add_column :amazon_sns_subscriptions, :status_changed_at, :datetime

    DB.exec("UPDATE amazon_sns_subscriptions SET status_changed_at = updated_at")
  end

  def down
    remove_column :amazon_sns_subscriptions, :status
    remove_column :amazon_sns_subscriptions, :status_changed_at
  end
end
