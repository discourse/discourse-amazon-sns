# frozen_string_literal: true

require 'aws-sdk-sns'

class AmazonSnsHelper
  def self.sns_client(client = nil)
    @client = client || Aws::SNS::Client.new(
      access_key_id: SiteSetting.amazon_sns_access_key_id,
      secret_access_key: SiteSetting.amazon_sns_secret_access_key,
      region: SiteSetting.amazon_sns_region
    )
  end

  def self.create_endpoint(token: "", platform: "ios")
    platform_application_arn = platform == "ios" ?
      SiteSetting.amazon_sns_apns_application_arn :
      SiteSetting.amazon_sns_gcm_application_arn

    begin
      response = sns_client.create_platform_endpoint(
        platform_application_arn: platform_application_arn,
        token: token
      )
    rescue Aws::SNS::Errors::ServiceError => e
      return render json: { errors: [e.message] }, status: 422
    end

    response.endpoint_arn
  end

  def self.get_endpoint_attributes(arn)
    begin
      resp = sns_client.get_endpoint_attributes(endpoint_arn: arn)
    rescue Aws::SNS::Errors::ServiceError => e
      return render json: { errors: [e.message] }, status: 422
    end
    resp.attributes
  end

  def self.delete_endpoint(arn)
    puts arn.inspect
    puts "delete endpoint hit"
    sns_client.delete_endpoint(endpoint_arn: arn)
  end

  def self.publish(target_arn, payload, unread)
    puts target_arn
    puts payload
    puts unread
    # payload[:topic_title]

    message = "@#{payload[:username]}: #{payload[:excerpt]}"

    iphone_notification = {
      aps: {
        alert: message,
        badge: unread
      },
      url: payload[:post_url]
    }

    sns_payload = {
      default: message,
      APNS_SANDBOX: iphone_notification.to_json,
      APNS: iphone_notification.to_json
    }

    begin
      resp = sns_client.publish(
        target_arn: target_arn,
        message: sns_payload.to_json,
        message_structure: "json"
      )
    rescue Aws::SNS::Errors::EndpointDisabled =>
      # cleanup if the endpoint is disabled (on launch, app will subscribe again)
      AmazonSnsSubscription.where(endpoint_arn: target_arn).destroy_all
      delete_endpoint(target_arn)
    end

  end

  def self.test_publish()
    target_arn = "arn:aws:sns:us-east-1:638650587766:endpoint/APNS_SANDBOX/PeshkuTestAppleDev/d36b414a-aad8-3562-afe1-f4ad6a20d0c3"
    iphone_notification = { aps: { alert: "@user1: Hey there Apple dude", badge: 1 }, url: "http://www.amazon.com" }

    sns_payload = {
      default: "Hey hey hey there",
      APNS_SANDBOX: iphone_notification.to_json, # needed for testing with dev certificate
      APNS: iphone_notification.to_json
    }

    puts sns_payload.to_json

    resp = sns_client.publish(
      target_arn: target_arn,
      message: sns_payload.to_json,
      message_structure: "json"
    )
  end
end
