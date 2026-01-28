# frozen_string_literal: true

module Api
  module V1
    class PushConfigController < BaseController
      skip_before_action :authenticate_request!
      skip_before_action :check_api_key_rate_limit
      skip_before_action :log_api_access

      def show
        if Rails.application.config.webpush.enabled.call
          render json: {
            enabled: true,
            vapid_public_key: Rails.application.config.webpush.vapid_public_key
          }
        else
          render json: { enabled: false }
        end
      end
    end
  end
end
