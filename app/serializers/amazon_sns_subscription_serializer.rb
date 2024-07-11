# frozen_string_literal: true

class AmazonSnsSubscriptionSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :device_token,
             :application_name,
             :platform,
             :endpoint_arn,
             :created_at,
             :updated_at,
             :status,
             :status_changed_at
end
