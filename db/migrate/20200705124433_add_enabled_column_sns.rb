# frozen_string_literal: true

class AddEnabledColumnSns < ActiveRecord::Migration[6.0]
  def change
    add_column :amazon_sns_subscriptions, :enabled, :integer, null: false, default: 1
  end
end
