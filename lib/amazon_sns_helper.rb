# frozen_string_literal: true

require "aws-sdk-sns"

class AmazonSnsHelper
  def self.sns_client(client = nil)
    opts = {}

    if SiteSetting.amazon_sns_secret_access_key && SiteSetting.amazon_sns_access_key_id
      opts[:access_key_id] = SiteSetting.amazon_sns_access_key_id
      opts[:secret_access_key] = SiteSetting.amazon_sns_secret_access_key
    end

    opts[:region] = SiteSetting.amazon_sns_region if SiteSetting.amazon_sns_region

    @client = client || Aws::SNS::Client.new(opts)
  end

  def self.create_endpoint(token: "", platform: "ios")
    platform_application_arn =
      (
        if platform == "ios"
          SiteSetting.amazon_sns_apns_application_arn
        else
          SiteSetting.amazon_sns_gcm_application_arn
        end
      )

    begin
      response =
        sns_client.create_platform_endpoint(
          platform_application_arn: platform_application_arn,
          token: token,
        )
    rescue Aws::SNS::Errors::ServiceError => e
      Rails.logger.error(e)
      return false
    end

    response.endpoint_arn
  end

  def self.get_endpoint_attributes(arn)
    begin
      resp = sns_client.get_endpoint_attributes(endpoint_arn: arn)
    rescue Aws::SNS::Errors::ServiceError
      return false
    end
    resp.attributes
  end

  def self.delete_endpoint(arn)
    sns_client.delete_endpoint(endpoint_arn: arn)
  end

  def self.publish_ios(user, target_arn, payload, unread)
    message = "@#{payload[:username]}: #{payload[:excerpt]}"
    url = "#{Discourse.base_url_no_prefix}#{payload[:post_url]}"

    iphone_notification = { aps: { alert: message, badge: unread }, url: url }

    sns_payload = {
      default: message,
      APNS_SANDBOX: iphone_notification.to_json,
      APNS: iphone_notification.to_json,
    }

    begin
      resp =
        sns_client.publish(
          target_arn: target_arn,
          message: sns_payload.to_json,
          message_structure: "json",
        )
      DiscourseEvent.trigger(:push_notification_sent, user, { url: url })
    rescue Aws::SNS::Errors::EndpointDisabled => e
      # mark local record disabled, only used for statistical purposes
      # if user launches again, app will delete row and resubscribe in SNS
      disable_arn_subscriptions(target_arn)
      delete_endpoint(target_arn)
    rescue Aws::SNS::Errors::InvalidParameter => e
      if e.message =~ /TargetArn/
        # somehow we have a wrong target_arn, cleanup locally only
        destroy_arn_subscriptions(target_arn)
      end
    end
  end

  def self.publish_android(user, target_arn, payload)
    message = "@#{payload[:username]}: #{payload[:excerpt]}"

    url = "#{Discourse.base_url_no_prefix}#{payload[:post_url]}"
    android_notification = {
      data: {
        message: message,
        url: url,
      },
      notification: {
        title: payload[:topic_title] || payload[:translated_title],
        body: message,
      },
    }

    sns_payload = { gcm: android_notification.to_json }

    begin
      resp =
        sns_client.publish(
          target_arn: target_arn,
          message: sns_payload.to_json,
          message_structure: "json",
        )
      DiscourseEvent.trigger(:push_notification_sent, user, { url: url })
    rescue Aws::SNS::Errors::EndpointDisabled => e
      # mark local record disabled, only used for statistical purposes
      # if user launches again, app will delete row and resubscribe in SNS
      disable_arn_subscriptions(target_arn)
      delete_endpoint(target_arn)
    rescue Aws::SNS::Errors::InvalidParameter => e
      if e.message =~ /TargetArn/
        # somehow we have a wrong target_arn, cleanup locally only
        destroy_arn_subscriptions(target_arn)
      end
    end
  end

  def self.disable_arn_subscriptions(target_arn)
    AmazonSnsSubscription.where(endpoint_arn: target_arn).update_all(
      status: AmazonSnsSubscription.statuses[:disabled],
      status_changed_at: Time.zone.now,
    )
  end

  def self.destroy_arn_subscriptions(target_arn)
    AmazonSnsSubscription.where(endpoint_arn: target_arn).destroy_all
  end

  def self.test_publish_ios
    target_arn =
      "arn:aws:sns:us-east-1:123456789012:endpoint/APNS_SANDBOX/AppleTest/c3fbd2be-3093-11ee-be56-0242ac120002"
    iphone_notification = {
      aps: {
        alert: "@user1: Hey there Apple dude",
        badge: 1,
      },
      url: "http://www.example.com",
    }

    sns_payload = {
      default: "Hey hey hey there",
      APNS_SANDBOX: iphone_notification.to_json, # needed for testing with dev certificate
      APNS: iphone_notification.to_json,
    }

    puts sns_payload.to_json

    resp =
      sns_client.publish(
        target_arn: target_arn,
        message: sns_payload.to_json,
        message_structure: "json",
      )
  end

  def self.test_publish_android
    target_arn =
      "arn:aws:sns:us-east-1:987654321098:endpoint/GCM/AndroidTest/f6d9c22c-3093-11ee-be56-0242ac120002"
    android_notification = {
      data: {
        message: "@user1: Hey there Android dude",
        url: "http://www.example.com",
      },
      notification: {
        title: "Notification title",
        body: "@user1: Hey there Android dude not. body",
      },
    }

    sns_payload = { gcm: android_notification.to_json }

    puts sns_payload.to_json

    resp =
      sns_client.publish(
        target_arn: target_arn,
        message: sns_payload.to_json,
        message_structure: "json",
      )
  end
end
