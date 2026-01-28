# frozen_string_literal: true

module Api
  module V1
    class PushSubscriptionsController < BaseController
      def create
        subscription = current_resource_owner.push_subscriptions.find_or_initialize_by(
          endpoint: subscription_params[:endpoint]
        )

        subscription.assign_attributes(
          p256dh_key: subscription_params.dig(:keys, :p256dh),
          auth_key: subscription_params.dig(:keys, :auth),
          user_agent: request.user_agent
        )

        if subscription.save
          render json: { id: subscription.id }, status: :created
        else
          render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        subscription = current_resource_owner.push_subscriptions.find(params[:id])
        subscription.destroy
        head :no_content
      end

      private

        def subscription_params
          params.require(:subscription).permit(:endpoint, keys: [ :p256dh, :auth ])
        end
    end
  end
end
