# frozen_string_literal: true

class ::AmazonSnsSubscriptionController < ::ApplicationController
  requires_plugin DiscourseAmazonSns::PLUGIN_NAME

  before_action :ensure_logged_in

  def create
    token = params.require(:token)
    application_name = params.require(:application_name)
    platform = params.require(:platform)
    if %w[ios android].exclude?(platform)
      raise Discourse::InvalidParameters, "Platform parameter should be ios or android."
    end

    existing_record = false

    if record = AmazonSnsSubscription.where(device_token: token).first
      endpoint_attrs = AmazonSnsHelper.get_endpoint_attributes(record.endpoint_arn)

      if endpoint_attrs && endpoint_attrs["Enabled"] == "true"
        existing_record = true
        record.update(user_id: current_user.id) if record.user_id != current_user.id

        if record.status == AmazonSnsSubscription.statuses[:disabled]
          record.update(
            status: AmazonSnsSubscription.statuses[:enabled],
            status_changed_at: Time.zone.now,
          )
        end
      else
        # delete existing record, delete endpoint, let new one be created
        AmazonSnsHelper.delete_endpoint(record.endpoint_arn)
        record.destroy
      end
    end

    unless existing_record
      endpoint_arn = AmazonSnsHelper.create_endpoint(token: token, platform: platform)
      unless endpoint_arn
        return render json: { errors: ["Missing endpoint_arn."] }, status: :unprocessable_content
      end

      record =
        AmazonSnsSubscription.create!(
          user_id: current_user.id,
          device_token: token,
          application_name: application_name,
          platform: platform,
          endpoint_arn: endpoint_arn,
          status_changed_at: Time.zone.now,
        )
    end

    render_serialized(record, AmazonSnsSubscriptionSerializer, root: false)
  end

  def disable
    token = params.require(:token)
    if record = AmazonSnsSubscription.where(device_token: token).first
      record.update(
        status: AmazonSnsSubscription.statuses[:disabled],
        status_changed_at: Time.zone.now,
      )

      render_serialized(record, AmazonSnsSubscriptionSerializer, root: false)
      return
    end

    raise Discourse::NotFound
  end
end
