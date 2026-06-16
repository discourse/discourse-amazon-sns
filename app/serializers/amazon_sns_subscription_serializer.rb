# frozen_string_literal: true

class AmazonSnsSubscriptionSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :application_name,
             :platform,
             :created_at,
             :updated_at,
             :status,
             :status_changed_at
end
