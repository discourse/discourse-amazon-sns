# frozen_string_literal: true

module Jobs
  class AmazonSnsNotification < Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      payload = args[:payload]
      unread = args[:unread]

      user.amazon_sns_subscriptions.each do |subscription|
        AmazonSnsHelper.publish(subscription.endpoint_arn, payload, unread)
      end
    end
  end
end
