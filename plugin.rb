# frozen_string_literal: true

# name: discourse-amazon-sns
# about: Enables push notifications via Amazon SNS. To be used in conjunction with a mobile app.
# version: 0.1
# authors: Penar Musaraj
# url: https://github.com/discourse/discourse-amazon-sns

enabled_site_setting :enable_amazon_sns_pns

module ::DiscourseAmazonSns
  PLUGIN_NAME = "discourse-amazon-sns"
end

after_initialize do
  require_relative "app/controllers/amazon_sns_controller"
  require_relative "app/models/amazon_sns_subscription"
  require_relative "lib/amazon_sns_helper"
  require_relative "lib/user_extension"
  require_relative "jobs/regular/amazon_sns_notification"

  Discourse::Application.routes.append do
    post "/amazon-sns/subscribe" => "amazon_sns_subscription#create"
    post "/amazon-sns/disable" => "amazon_sns_subscription#disable"
  end

  User.prepend(DiscourseAmazonSns::UserExtension)

  on(:push_notification) do |user, payload|
    if user.amazon_sns_subscriptions.exists?
      send_notification =
        DiscoursePluginRegistry.apply_modifier(:amazon_sns_send_notification, true, user, payload)

      next if !send_notification

      unread_total = user.unread_notifications + user.unread_high_priority_notifications
      Jobs.enqueue(
        :amazon_sns_notification,
        user_id: user.id,
        payload: payload,
        unread: unread_total,
      )
    end
  end
end
