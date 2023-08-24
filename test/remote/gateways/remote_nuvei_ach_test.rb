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
    options                         = @options.dup
    options[:order_id]              = generate_unique_id
    mock_response                   = successful_create_order_response
    mock_response[:clientRequestId] = options[:order_id]

    # Set LIVE_TEST=true in your environment to run this with live API calls
    if ENV['LIVE_TEST'] != 'true'
      @gateway.expects(:ssl_request).returns(mock_response.to_json)
    end

    response           = @gateway.create_order(@amount, options)

    assert_instance_of Response, response
    assert_success response

    # These are based on the options
    assert_equal options[:order_id],                  response.params['clientRequestId']
    assert_equal options[:transaction_id],            response.params['clientUniqueId']
    assert_equal @gateway.options[:merchant_id],      response.params['merchantId']
    assert_equal @gateway.options[:merchant_site_id], response.params['merchantSiteId']
    assert_equal options[:customer_id],               response.params['userTokenId']

    # These are always unique
    assert response.params['clientRequestId']
    assert response.params['internalRequestId']
    assert response.params['orderId']
    assert response.params['sessionToken']
  end

  ############################################################################
  # Mock Responses                                                           #
  ############################################################################

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

