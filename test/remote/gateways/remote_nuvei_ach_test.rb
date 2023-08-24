require 'test_helper'
require 'securerandom'

class RemoteNuveiAchTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiAchGateway.new(fixtures(:nuvei_ach))
    @amount  = 125
    @options = {
      billing_address: address,
      customer_id:     'd3btor-1d',
      description:     'Fake purchase',
      email:           'test@test.com',
      ip:              '127.0.0.1',
      transaction_id:  'tr4ns4ct10n-1d'
    }
  end

  def test_create_session
    # TODO: should login and create a session
  end

  def test_successful_create_order
    # TODO: should create an order
    # @gateway.expects(:ssl_request).returns(successful_create_order_response.to_json) unless ENV['LIVE_TEST'] == 'true'
    options            = @options.dup
    options[:order_id] = generate_unique_id
    response           = @gateway.create_order(@amount, options)

    assert_instance_of Response, response
    assert_success response

    # These are based on the options
    assert_equal options[:transaction_id],            response.params['clientUniqueId']
    assert_equal 0,                                   response.params['errCode']
    assert_equal @gateway.options[:merchant_id],      response.params['merchantId']
    assert_equal @gateway.options[:merchant_site_id], response.params['merchantSiteId']
    assert_equal options[:order_id],                  response.params['clientRequestId']
    assert_equal options[:customer_id],               response.params['userTokenId']

    # These are always unique
    assert response.params['sessionToken']
    assert response.params['clientRequestId']
    assert response.params['internalRequestId']
    assert response.params['orderId']
  end

  def successful_create_order_response(
    client_request_id:   "1eac1321fadfbece95f7861333129847",
    client_unique_id:    "tr4ns4ct10n-1d",
    err_code:            "0",
    internal_request_id: "759508088",
    merchant_id:         "6681232478277060313",
    merchant_site_id:    "239358",
    order_id:            "385235308",
    reason:              "",
    session_token:       "a5e3051a-7e97-45eb-a602-328b2eb9fb60",
    status:              "SUCCESS",
    user_token_id:       'd3btor-1d',
    version:             "1.0"
  )
    {
      clientRequestId:   "#{client_request_id}",
      clientUniqueId:    "#{client_unique_id}",
      errCode:           "#{err_code}",
      internalRequestId: "#{internal_request_id}",
      merchantId:        "#{merchant_id}",
      merchantSiteId:    "#{merchant_site_id}",
      orderId:           "#{order_id}",
      reason:            "#{reason}",
      sessionToken:      "#{session_token}",
      status:            "#{status}",
      userTokenId:       "#{user_token_id}",
      version:           "#{version}",
    }
  end
end

