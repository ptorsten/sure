# frozen_string_literal: true

require "test_helper"

class PushNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM",
      auth_key: "tBHItJI5svbpez7KI4CCXg"
    )

    Rails.application.config.webpush.vapid_public_key = "test_public_key"
    Rails.application.config.webpush.vapid_private_key = "test_private_key"
  end

  test "sends notification to user" do
    Webpush.expects(:payload_send).once.returns(true)

    result = PushNotificationService.notify(
      user: @user,
      title: "Test",
      body: "Hello"
    )

    assert result
  end

  test "handles expired subscription" do
    mock_response = OpenStruct.new(body: "Subscription expired", inspect: "410 Gone")
    Webpush.expects(:payload_send).raises(Webpush::ExpiredSubscription.new(mock_response, "fcm.googleapis.com"))

    assert_difference "PushSubscription.count", -1 do
      PushNotificationService.notify(
        user: @user,
        title: "Test",
        body: "Hello"
      )
    end
  end

  test "skips when push not configured" do
    Rails.application.config.webpush.vapid_public_key = nil

    Webpush.expects(:payload_send).never

    PushNotificationService.notify(
      user: @user,
      title: "Test",
      body: "Hello"
    )
  end
end
