# frozen_string_literal: true

RSpec.describe AmazonSnsHelper do
  fab!(:user)
  let(:test_arn) { "sample:arn2" }
  let!(:subscription) do
    AmazonSnsSubscription.create!(
      user_id: user.id,
      device_token: "some_token",
      application_name: "application_name",
      platform: "ios",
      endpoint_arn: test_arn,
    )
  end
  let(:mock_response) { stub }

  before do
    SiteSetting.amazon_sns_region = "us-west-2"
    SiteSetting.amazon_sns_access_key_id = "access_key_id"
    SiteSetting.amazon_sns_secret_access_key = "secret_key"
    SiteSetting.amazon_sns_apns_application_arn = "test_apple_arn"
  end

  context "when the SNS endpoint has been disabled" do
    before do
      Aws::SNS::Client
        .any_instance
        .expects(:publish)
        .raises(Aws::SNS::Errors::EndpointDisabled.new(stub, "message"))
      Aws::SNS::Client
        .any_instance
        .expects(:delete_endpoint)
        .with(endpoint_arn: test_arn)
        .at_least(1)
    end

    it "disables the subscription and deletes the endpoint for publish_ios" do
      described_class.publish_ios(user, test_arn, {}, true)
      subscription.reload
      expect(subscription.status).to eq(AmazonSnsSubscription.statuses[:disabled])
      expect(subscription.status_changed_at).not_to eq(nil)
    end

    it "disables the subscription and deletes the endpoint for publish_android" do
      described_class.publish_android(user, test_arn, {})
      subscription.reload
      expect(subscription.status).to eq(AmazonSnsSubscription.statuses[:disabled])
      expect(subscription.status_changed_at).not_to eq(nil)
    end
  end

  context "when the SNS endpoint does not exist with TargetArn error" do
    before do
      Aws::SNS::Client
        .any_instance
        .expects(:publish)
        .raises(Aws::SNS::Errors::InvalidParameter.new(stub, "TargetArn does not exist"))
    end

    it "destroys the subscription for publish_ios" do
      described_class.publish_ios(user, test_arn, {}, true)
      expect(AmazonSnsSubscription.find_by(id: subscription.id)).to eq(nil)
    end

    it "destroys the subscription for publish_android" do
      described_class.publish_android(user, test_arn, {})
      expect(AmazonSnsSubscription.find_by(id: subscription.id)).to eq(nil)
    end
  end

  describe "publish_android" do
    let(:client) { Aws::SNS::Client.new(stub_responses: true) }

    before do
      allow(described_class).to receive(:sns_client).and_return(client)
      allow(client).to receive(:publish).and_return(mock_response)
    end

    context "when use_title_and_body is true" do
      let(:payload) do
        { use_title_and_body: true, title: "Test Title", body: "Test Body", post_url: "/test/url" }
      end

      it "uses title and body directly" do
        described_class.publish_android(user, test_arn, payload)

        expected_message = {
          gcm: {
            data: {
              message: "Test Body",
              url: "#{Discourse.base_url_no_prefix}/test/url",
            },
            notification: {
              title: "Test Title",
              body: "Test Body",
            },
          }.to_json,
        }.to_json

        expect(client).to have_received(:publish).with(
          target_arn: test_arn,
          message: expected_message,
          message_structure: "json",
        )
      end
    end

    context "when use_title_and_body is false" do
      let(:payload) do
        {
          topic_title: "Topic Title",
          username: "username",
          excerpt: "Excerpt",
          post_url: "/test/url",
        }
      end

      it "generates a message using topic title and excerpt" do
        allow(described_class).to receive(:generate_message).and_return("@username: Excerpt")

        described_class.publish_android(user, test_arn, payload)

        expected_message = {
          gcm: {
            data: {
              message: "@username: Excerpt",
              url: "#{Discourse.base_url_no_prefix}/test/url",
            },
            notification: {
              title: "Topic Title",
              body: "@username: Excerpt",
            },
          }.to_json,
        }.to_json

        expect(client).to have_received(:publish).with(
          target_arn: test_arn,
          message: expected_message,
          message_structure: "json",
        )
      end
    end
  end
end
