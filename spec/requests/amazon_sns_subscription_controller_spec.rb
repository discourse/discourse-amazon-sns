# frozen_string_literal: true

require 'rails_helper'
require File.expand_path("../../../lib/amazon_sns_helper.rb", __FILE__)

RSpec.describe AmazonSnsSubscriptionController do

  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  context '#create' do
    before do
      SiteSetting.enable_amazon_sns_pns = true
      SiteSetting.amazon_sns_access_key_id = "access_key_id"
      SiteSetting.amazon_sns_secret_access_key = "secret_key"
      SiteSetting.amazon_sns_apns_application_arn = "test_apple_arn"

      sign_in(user)
    end

    it 'creates a new subscription' do
      Aws.config[:sns] = {
        stub_responses: {
          create_platform_endpoint: {
            endpoint_arn: "sample:arn"
          }
        }
      }

      post '/amazon-sns/subscribe.json', params: {
        token: "123123123123",
        application_name: "Penar's phone",
        platform: "ios"
      }

      expect(response.status).to eq(200)
      expect(user.amazon_sns_subscriptions.length).to eq(1)
    end

    it 'accepts only ios/android as platform param' do
      post '/amazon-sns/subscribe.json', params: {
        token: "123123123123",
        application_name: "Penar's phone",
        platform: "windows"
      }

      json = JSON.parse(response.body)

      expect(response.status).to eq(400)
      expect(json["error_type"]).to eq("invalid_parameters")
    end

    it 'replaces a disabled endpoint with a new one' do
      AmazonSnsHelper.expects(:get_endpoint_attributes).with("sample:arn2")
        .returns('Enabled' => 'false')

      AmazonSnsHelper.expects(:delete_endpoint).with("sample:arn2")
      AmazonSnsHelper.expects(:create_endpoint).returns("updated_arn")

      AmazonSnsSubscription.create!(
        user_id: user.id,
        device_token: "some_token",
        application_name: "application_name",
        platform: "ios",
        endpoint_arn: "sample:arn2"
      )

      post '/amazon-sns/subscribe.json', params: {
        token: "some_token",
        application_name: "application_name",
        platform: "ios"
      }

      expect(response.status).to eq(200)
      lastSubscription = AmazonSnsSubscription.last

      expect(lastSubscription.device_token).to eq("some_token")
      expect(lastSubscription.endpoint_arn).to eq("updated_arn")
    end

    it 'replaces user id associated with endpoint if different from existing user id' do
      AmazonSnsHelper.expects(:get_endpoint_attributes).with("testing:arn")
        .returns('Enabled' => 'true')

      AmazonSnsSubscription.create!(
        user_id: user.id,
        device_token: "unique_app_token",
        application_name: "application_name",
        platform: "ios",
        endpoint_arn: "testing:arn"
      )

      sign_in(user2)

      post '/amazon-sns/subscribe.json', params: {
        token: "unique_app_token",
        application_name: "application_name",
        platform: "ios"
      }

      expect(response.status).to eq(200)
      lastSubscription = AmazonSnsSubscription.last

      expect(lastSubscription.device_token).to eq("unique_app_token")
      expect(lastSubscription.user_id).to eq(user2.id)
      expect(lastSubscription.endpoint_arn).to eq("testing:arn")
    end

  end
end
