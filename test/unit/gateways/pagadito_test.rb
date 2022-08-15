require 'test_helper'

class PagaditoTest < Test::Unit::TestCase
  def setup
    @gateway = PagaditoGateway.new(username: 'username', wsk: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: 1,
      email: 'test@test.com',
      ip: '50.93.92.185',
      device_id: '12345',
      currency: 'USD',
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '1C917C4D', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    %(
      {
        "response_code": "PG200-00",
        "response_message": "Operation successful",
        "request_id": "4bcfc84b4add786f2689d98844107cf0",
        "customer_reply": {
            "payment_token": "cus_4aaa23c6e7cf1fad",
            "authorization": "1C917C4D",
            "merchantTransactionId": "1",
            "totalAmount": "100.00",
            "firstName": "Longbob",
            "lastName": "Longsen",
            "paymentDate": "2022-08-14T20:45:40-06:00"
        },
        "request_date": "2022-08-14T20:45:43-06:00"
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "response_code": "PG400-07",
        "response_message": "Currency not supported for Pagadito.",
        "request_date": "2022-08-14T20:45:37-06:00"
      }
    )
  end
end
