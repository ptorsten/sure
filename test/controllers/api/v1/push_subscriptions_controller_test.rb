# frozen_string_literal: true

require "test_helper"

class Api::V1::PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @token = create_oauth_token_for(@user)
    @subscription_params = {
      subscription: {
        endpoint: "https://fcm.googleapis.com/fcm/send/test123",
        keys: {
          p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM",
          auth: "tBHItJI5svbpez7KI4CCXg"
        }
      }
    }
  end

  test "create subscription with valid token" do
    assert_difference "PushSubscription.count", 1 do
      post api_v1_push_subscriptions_url,
        params: @subscription_params,
        headers: { "Authorization" => "Bearer #{@token}" },
        as: :json
    end

    assert_response :created
    assert_equal @subscription_params[:subscription][:endpoint], PushSubscription.last.endpoint
  end

  test "create subscription requires authentication" do
    post api_v1_push_subscriptions_url, params: @subscription_params, as: :json
    assert_response :unauthorized
  end

  test "delete subscription" do
    subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://example.com/push/456",
      p256dh_key: "key",
      auth_key: "auth"
    )

    assert_difference "PushSubscription.count", -1 do
      delete api_v1_push_subscription_url(subscription),
        headers: { "Authorization" => "Bearer #{@token}" }
    end

    assert_response :no_content
  end

  private

  def create_oauth_token_for(user)
    app = Doorkeeper::Application.find_or_create_by!(name: "Test App") do |a|
      a.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      a.scopes = "read_write"
    end

    token = Doorkeeper::AccessToken.create!(
      application: app,
      resource_owner_id: user.id,
      scopes: "read_write"
    )

    token.plaintext_token
  end
end
