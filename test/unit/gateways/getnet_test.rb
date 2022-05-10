require 'test_helper'

class GetnetTest < Test::Unit::TestCase
  def setup
    @gateway = GetnetGateway.new(username: 'username', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_build_access_token_headers
    response = @gateway.send(:build_access_token_headers)
    auth = response['Authorization']
    # Expecting base64 encoded version of "username:password"
    assert_equal auth, 'Basic dXNlcm5hbWU6cGFzc3dvcmQ='
  end

  def test_success_acquire_access_token
    @gateway.expects(:ssl_post)
      .with('https://api-sandbox.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)

    response = @gateway.send(:acquire_access_token)
    
    assert_equal response, "abc12345-6c4d-4d92-9f3f-81385966693f"
  end
  
  def test_failure_acquire_access_token
    @gateway.expects(:ssl_post)
      .with('https://api-sandbox.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(failure_oauth_access_token)
    assert_raise Error do
      response = @gateway.send(:acquire_access_token)
    end
  end
  

  # def test_successful_purchase
  #   @gateway.expects(:ssl_post).returns(successful_purchase_response)

  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response

  #   assert_equal 'REPLACE', response.authorization
  #   assert response.test?
  # end

  # def test_failed_purchase
  #   @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  # end

  # def test_successful_authorize; end

  # def test_failed_authorize; end

  # def test_successful_capture; end

  # def test_failed_capture; end

  # def test_successful_refund; end

  # def test_failed_refund; end

  # def test_successful_void; end

  # def test_failed_void; end

  # def test_successful_verify; end

  # def test_successful_verify_with_failed_void; end

  # def test_failed_verify; end

  # def test_scrub
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  # private

  # def pre_scrubbed
  #   '
  #     Run the remote tests for this gateway, and then put the contents of transcript.log here.
  #   '
  # end

  # def post_scrubbed
  #   '
  #     Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
  #     Things to scrub:
  #       - Credit card number
  #       - CVV
  #       - Sensitive authentication details
  #   '
  # end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_getnet_test.rb \
        -n test_successful_purchase
    )
  end

  # def failed_purchase_response; end

  # def successful_authorize_response; end

  # def failed_authorize_response; end

  # def successful_capture_response; end

  # def failed_capture_response; end

  # def successful_refund_response; end

  # def failed_refund_response; end

  # def successful_void_response; end

  # def failed_void_response; end

  def successful_oauth_access_token
    <<-RESPONSE
    {
      "access_token": "abc12345-6c4d-4d92-9f3f-81385966693f",
      "token_type":"Bearer",
      "expires_in":3600,
      "scope":"oob"
    }
    RESPONSE
  end

  def failure_oauth_access_token
    <<-RESPONSE
    {
      "error":"invalid_client",
      "error_description":"The given client credentials were not valid"
    }
    RESPONSE
  end
end
