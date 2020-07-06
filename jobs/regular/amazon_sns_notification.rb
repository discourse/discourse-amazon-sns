# frozen_string_literal: true

module Jobs
  class AmazonSnsNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      payload = args[:payload]
      unread = args[:unread]

      user.amazon_sns_subscriptions.each do |subscription|
        next if subscription.enabled == 0

        if subscription.platform == "ios"
          AmazonSnsHelper.publish_ios(subscription.endpoint_arn, payload, unread)
        else
          AmazonSnsHelper.publish_android(subscription.endpoint_arn, payload)
        end
      end
    end
  end
end
