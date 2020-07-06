# frozen_string_literal: true

class AmazonSnsSubscription < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: amazon_sns_subscriptions
#
#  id               :bigint           not null, primary key
#  user_id          :integer          not null
#  device_token     :string           not null
#  application_name :string           not null
#  platform         :string           not null
#  endpoint_arn     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  enabled          :integer          not null
#
# Indexes
#
#  index_amazon_sns_subscriptions_on_device_token  (device_token) UNIQUE
