# frozen_string_literal: true

require 'rails_helper'
require File.expand_path("../../../lib/amazon_sns_helper.rb", __FILE__)

RSpec.describe AmazonSnsSubscriptionController do

  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  before do
    SiteSetting.enable_amazon_sns_pns = true
    SiteSetting.amazon_sns_region = "us-east-1"
    SiteSetting.amazon_sns_access_key_id = "access_key_id"
    SiteSetting.amazon_sns_secret_access_key = "secret_key"
    SiteSetting.amazon_sns_apns_application_arn = "test_apple_arn"

    Aws.config[:sns] = {
      stub_responses: {
        create_platform_endpoint: {
          endpoint_arn: "sample:arn"
        }
      }
    }

    sign_in(user)
  end

  context '#create' do
    it 'creates a new subscription' do
      post '/amazon-sns/subscribe.json', params: {
        token: "123123123123",
        application_name: "Penar's phone",
        platform: "ios"
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(Time.parse(json["status_changed_at"])).to be_within(10.seconds).of Time.now
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
      expect(lastSubscription.status).to eq(AmazonSnsSubscription.statuses[:enabled])
    end

    it 'replaces an endpoint from wrong region with a new one' do
      AmazonSnsHelper.expects(:get_endpoint_attributes).with("sample:arn2")
        .returns(false)

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

      expect(lastSubscription.status).to eq(AmazonSnsSubscription.statuses[:enabled])
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
      expect(lastSubscription.status).to eq(AmazonSnsSubscription.statuses[:enabled])
    end

    it 'updates a disabled subscription, reenabling it' do
      token = "test123";

      post '/amazon-sns/subscribe.json', params: {
        token: token,
        application_name: "Penar's phone",
        platform: "ios"
      }
      expect(response.status).to eq(200)

      post '/amazon-sns/disable.json', params: {token: token}
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq(AmazonSnsSubscription.statuses[:disabled])

      AmazonSnsHelper.expects(:get_endpoint_attributes).with("sample:arn")
        .returns('Enabled' => 'true')

        post '/amazon-sns/subscribe.json', params: {
        token: token,
        application_name: "Penar's phone",
        platform: "ios"
      }
      expect(response.status).to eq(200)
      final_json = JSON.parse(response.body)
      expect(final_json["status"]).to eq(AmazonSnsSubscription.statuses[:enabled])
    end
  end

  context '#disable' do
    it 'marks a subscription as disabled' do
      post '/amazon-sns/subscribe.json', params: {
        token: "123123123123",
        application_name: "Penar's phone",
        platform: "ios"
      }

      expect(response.status).to eq(200)

      post '/amazon-sns/disable.json', params: {
        token: "123123123123",
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq(AmazonSnsSubscription.statuses[:disabled])
    end

    it 'fails when token does not match' do
      post '/amazon-sns/disable.json', params: {
        token: "no-bueno",
      }

      expect(response.status).to eq(404)
    end
  end
end
