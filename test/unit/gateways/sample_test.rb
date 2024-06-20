require 'test_helper'

class SampleTest < Test::Unit::TestCase
  def setup
    @gateway = SampleGateway.new(login: 'login', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Successful transfer', response.message
    assert response.test?
  end

  def test_successful_authorize; end

  def test_failed_authorize; end

  def test_successful_capture; end

  def test_failed_capture; end

  def test_successful_refund; end

  def test_failed_refund; end

  def test_successful_void; end

  def test_failed_void; end

  def test_successful_verify; end

  def test_successful_verify_with_failed_void; end

  def test_failed_verify; end

  private

  def successful_purchase_response
    JSON.generate(
      "data" =>
        JSON.generate(
          { "amount" => "0.50", "currency" => "USD", "avs_response" => "R", "cvv_response" => "M",
            "state" => "success", "message" => "Successful transfer" }
        )
    )
  end

  def failed_purchase_response; end

  def successful_authorize_response; end

  def failed_authorize_response; end

  def successful_capture_response; end

  def failed_capture_response; end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response; end

  def failed_void_response; end
end
