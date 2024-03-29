# frozen_string_literal: true

module Jobs
  class AmazonSnsNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      payload = args[:payload]
      unread = args[:unread]

      user.amazon_sns_subscriptions.each do |subscription|
        next if subscription.status == AmazonSnsSubscription.statuses[:disabled]

        if subscription.platform == "ios"
          AmazonSnsHelper.publish_ios(user, subscription.endpoint_arn, payload, unread)
        else
          AmazonSnsHelper.publish_android(user, subscription.endpoint_arn, payload)
        end
      end
    end
  end
end
