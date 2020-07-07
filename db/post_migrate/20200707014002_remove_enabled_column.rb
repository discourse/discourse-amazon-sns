# frozen_string_literal: true

class RemoveEnabledColumn < ActiveRecord::Migration[6.0]
  def change
    remove_column :amazon_sns_subscriptions, :enabled
  end
end
