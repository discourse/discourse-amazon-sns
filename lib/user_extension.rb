# frozen_string_literal: true

module DiscourseAmazonSns
  module UserExtension
    extend ActiveSupport::Concern

    prepended { has_many :amazon_sns_subscriptions, dependent: :delete_all }
  end
end
