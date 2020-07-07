# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AmazonSnsHelper do
  fab!(:user) { Fabricate(:user) }
  let!(:subscription) do 
    AmazonSnsSubscription.create!(
      user_id: user.id,
      device_token: "some_token",
      application_name: "application_name",
      platform: "ios",
      endpoint_arn: "sample:arn2"
    )
  end
  let(:mock_response) { stub }

  before do
    SiteSetting.amazon_sns_region = 'us-west-2'
  end
  
  context "when the SNS endpoint has been disabled" do
    before do
      Aws::SNS::Client.any_instance.expects(:publish).raises(
        Aws::SNS::Errors::EndpointDisabled.new(stub, "message")
      )
      Aws::SNS::Client.any_instance.expects(:delete_endpoint).with(
        endpoint_arn: "sample:arn2"
      ).at_least(1)
    end

    it "disables the subscription and deletes the endpoint for publish_ios" do
      described_class.publish_ios("sample:arn2", {}, true)
      subscription.reload
      expect(subscription.status).to eq(AmazonSnsSubscription.statuses[:disabled])
      expect(subscription.status_changed_at).not_to eq(nil)
    end

    it "disables the subscription and deletes the endpoint for publish_android" do
      described_class.publish_android("sample:arn2", {})
      subscription.reload
      expect(subscription.status).to eq(AmazonSnsSubscription.statuses[:disabled])
      expect(subscription.status_changed_at).not_to eq(nil)
    end
  end

  context "when the SNS endpoint does not exist with TargetArn error" do
    before do
      Aws::SNS::Client.any_instance.expects(:publish).raises(
        Aws::SNS::Errors::InvalidParameter.new(stub, "TargetArn does not exist")
      )
    end

    it "destroys the subscription for publish_ios" do
      described_class.publish_ios("sample:arn2", {}, true)
      expect(AmazonSnsSubscription.find_by(id: subscription.id)).to eq(nil)
    end

    it "destroys the subscription for publish_android" do
      described_class.publish_android("sample:arn2", {})
      expect(AmazonSnsSubscription.find_by(id: subscription.id)).to eq(nil)
    end
  end

  def mock_publish
    Aws::SNS::Client.any_instance.expects(:publish).returns(mock_response).at_least(1)
  end
end
