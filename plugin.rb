# frozen_string_literal: true

# name: discourse-amazon-sns-pns
# about: Enables push notifications via Amazon SNS. To be used in conjunction with a mobile app.
# version: 0.1
# authors: Penar Musaraj
# url: https://github.com/discourse/discourse-amazon-sns-pns

enabled_site_setting :enable_amazon_sns_pns
enabled_site_setting_filter :amazon_sns

after_initialize do
  require File.expand_path("../app/models/amazon_sns_subscription.rb", __FILE__)
  require File.expand_path("../lib/amazon_sns_helper.rb", __FILE__)
  require File.expand_path('../jobs/regular/amazon_sns_notification.rb', __FILE__)

  class ::AmazonSnsSubscriptionController < ::ApplicationController
    before_action :ensure_logged_in

    def create
      token = params.require(:token)
      application_name = params.require(:application_name)
      platform = params.require(:platform)
      if ["ios", "android"].exclude?(platform)
        raise Discourse::InvalidParameters, "Platform parameter should be ios or android."
      end

      existing_record = false

      if record = AmazonSnsSubscription.where(device_token: token).first
        endpoint_attrs = AmazonSnsHelper.get_endpoint_attributes(record.endpoint_arn)
        if endpoint_attrs["Enabled"] == "true"
          existing_record = true
        else
          # delete existing record, delete endpoint, let new one be created
          AmazonSnsHelper.delete_endpoint(record.endpoint_arn)
          record.destroy
        end
      end

      unless existing_record
        endpoint_arn = AmazonSnsHelper.create_endpoint(token: token, platform: platform)
        unless endpoint_arn
          return render json: { errors: ["Missing endpoint_arn."] }, status: 422
        end

        record = AmazonSnsSubscription.create!(
          user_id: current_user.id,
          device_token: token,
          application_name: application_name,
          platform: platform,
          endpoint_arn: endpoint_arn
        )
      end

      render json: record
    end
  end

  Discourse::Application.routes.append do
    post '/amazon-sns/subscribe' => "amazon_sns_subscription#create"
  end

  User.class_eval do
    has_many :amazon_sns_subscriptions, dependent: :delete_all
  end

  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    if user.amazon_sns_subscriptions.exists?
      unread_total = user.unread_notifications + user.unread_private_messages
      Jobs.enqueue(:amazon_sns_notification, user_id: user.id, payload: payload, unread: unread_total)
    end
  end
end
