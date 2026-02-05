# frozen_string_literal: true

class PushNotificationService
  class << self
    def notify(user:, title:, body:, path: "/", tag: nil, require_interaction: false)
      return false unless enabled?

      user.push_subscriptions.find_each do |subscription|
        send_to_subscription(subscription, title:, body:, path:, tag:, require_interaction:)
      end

      true
    end

    def notify_all(title:, body:, path: "/", tag: nil)
      return false unless enabled?

      PushSubscription.find_each do |subscription|
        send_to_subscription(subscription, title:, body:, path:, tag:)
      end

      true
    end

    private

      def enabled?
        Rails.application.config.webpush.enabled.call
      end

      def send_to_subscription(subscription, title:, body:, path:, tag:, require_interaction: false)
        message = {
          title: title,
          body: body,
          path: path,
          tag: tag,
          requireInteraction: require_interaction
        }.compact.to_json

        Webpush.payload_send(
          message: message,
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh_key,
          auth: subscription.auth_key,
          vapid: {
            subject: Rails.application.config.webpush.vapid_subject,
            public_key: Rails.application.config.webpush.vapid_public_key,
            private_key: Rails.application.config.webpush.vapid_private_key
          }
        )
      rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription
        subscription.destroy
      rescue Webpush::Error => e
        Rails.logger.error("Push notification failed: #{e.message}")
      end
  end
end
