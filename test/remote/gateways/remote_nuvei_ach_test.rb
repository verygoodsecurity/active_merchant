require 'test_helper'
require 'securerandom'

class RemoteNuveiAchTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiAchGateway.new(fixtures(:nuvei_ach))
    @amount  = 125
    @options = {
      order_id:        1,
      billing_address: address,
      description:     'Fake purchase',
      ip:              '127.0.0.1',
      email:           'test@test.com'
    }
  end

  def test_create_session
    # TODO: should login and create a session
  end

  def test_successful_create_order
    @gateway.expects(:ssl_request).returns(successful_create_order_response.to_json)
    # TODO: should create an order
    options                  = @options.dup
    options[:order_id]       = generate_unique_id
    options[:user_token_id]  = 'd3btor-1d'
    options[:transaction_id] = 'tr4ns4ct10n-1d'
    response                 = @gateway.create_order(@amount, options)

    successful_create_order_response.each do |key, value|
      assert_equal value, response.params[key], "key: #{key}"
    end

    assert_success response
    assert_equal 'Succeeded', response.message
    # Ensure that the authorization has a pipe to separate transactionId and user_payment_option_id
    assert response.authorization.include? "|"
  end

  def successful_create_order_response(
    client_request_id: "1eac1321fadfbece95f7861333129847",
    err_code: "0",
    internal_request_id: "759508088",
    merchant_id: "6681232478277060313",
    merchant_site_id: "239358",
    order_id: "385235308",
    reason: "",
    session_token: "a5e3051a-7e97-45eb-a602-328b2eb9fb60",
    status: "SUCCESS",
    version: "1.0"
  )
    {
      "clientRequestId":   "#{client_request_id}",
      "errCode":           "#{err_code}",
      "internalRequestId": "#{internal_request_id}",
      "merchantId":        "#{merchant_id}",
      "merchantSiteId":    "#{merchant_site_id}",
      "orderId":           "#{order_id}",
      "reason":            "#{reason}",
      "sessionToken":      "#{session_token}",
      "status":            "#{status}",
      "version":           "#{version}",
    }
  end
end

