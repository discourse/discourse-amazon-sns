# frozen_string_literal: true

# name: discourse-amazon-sns-pns
# about: Enables push notifications via Amazon SNS. To be used in conjunction with a mobile app.
# version: 0.1
# authors: Penar Musaraj
# url: https://github.com/discourse/discourse-amazon-sns

enabled_site_setting :enable_amazon_sns_pns

after_initialize do
  require File.expand_path("../app/models/amazon_sns_subscription.rb", __FILE__)
  require File.expand_path("../lib/amazon_sns_helper.rb", __FILE__)
  require File.expand_path(
            "../jobs/regular/amazon_sns_notification.rb",
            __FILE__
          )
  require File.expand_path(
            "../app/controllers/amazon_sns_controller.rb",
            __FILE__
          )

  Discourse::Application.routes.append do
    post "/amazon-sns/subscribe" => "amazon_sns_subscription#create"
    post "/amazon-sns/disable" => "amazon_sns_subscription#disable"
  end

  User.class_eval { has_many :amazon_sns_subscriptions, dependent: :delete_all }

  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    if user.amazon_sns_subscriptions.exists?
      unread_total =
        user.unread_notifications + user.unread_high_priority_notifications
      Jobs.enqueue(
        :amazon_sns_notification,
        user_id: user.id,
        payload: payload,
        unread: unread_total
      )
    end
  end
end
