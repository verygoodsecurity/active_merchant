require 'test_helper'

class RemotePagaditoTest < Test::Unit::TestCase
  def setup
    @gateway = PagaditoGateway.new(fixtures(:pagadito))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
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
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_only_first_name
    cc = @credit_card.dup
    cc.name = 'Tester Testerson'
    cc.last_name = nil
    response = @gateway.purchase(@amount, cc, @options)
    assert_failure response
    assert_equal 'Invalid format data for field: lastName', response.message
  end

  def test_failed_purchase_bad_currency
    opts = @options.clone
    opts[:currency] = 'CAD'
    response = @gateway.purchase(@amount, @credit_card, opts)
    assert_failure response
    assert_equal 'Currency not supported for Pagadito.', response.message
  end

end
