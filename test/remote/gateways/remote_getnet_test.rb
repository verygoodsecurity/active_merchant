require 'test_helper'

class RemoteGetnetTest < Test::Unit::TestCase
  def setup
    @gateway = GetnetGateway.new(fixtures(:getnet))

    addr = address
    addr[:zip] = '90230060'
    addr[:country] = 'Brasil'
    addr[:city] = 'Porto Alegre'
    addr[:state] = 'RS'
    addr[:address1] = '1000 Av. Brasil Room'
    @amount = 100
    card = credit_card('5155901222280001', {:name => 'JOAO DA SILVA', :month => 01, :year => 25, :verification_value => '123', :brand => 'mastercard'})
    @credit_card = card
    @declined_card = credit_card('5155901222260003')
    @options = {
      order_id: 1,
      customer_id: '12345',
      billing_address: addr,
      description: 'Store Purchase',
      device_id: '12345610500',
      ip: '127.0.0.1',
      email: 'aceitei@getnet.com.br',
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'transaction approved', response.message
  end

  def test_successful_purchase_test_mode_option
    @gateway.expects(:test?).at_least_once.returns(false)
    ops = @options
    ops[:test_mode] = true
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'transaction approved', response.message
  end

  def test_failed_purchase_declined_card
    options = @options.dup
    options[:email] = 'recusada@getnet.com.br'
    response = @gateway.purchase(5, @declined_card, options)
    assert_failure response
    assert_equal 'Failed', response.message
  end

  def test_failed_purchase_bad_amount
    response = @gateway.purchase(-5, @credit_card, @options)
    assert_failure response
    assert_equal 'amount is invalid', response.message
  end

  ## def test_successful_purchase_3ds
  ##   options = @options.dup
  ##   options[:three_d_secure] = {
  ##     :eci => "st",
  ##     :ucaf => "1234567890123456789012345678901234567890",
  ##     :xid => "XIDingstringstringstringstringstringstri",
  ##     :tdsdsxid => "dbdcb82d-63c5-496f-ae27-1ecfc3a8dbec",
  ##     :tdsver => "2.1.0"
  ##   }
  ##   card = @credit_card.dup
  ##   card.number = "40000000000001000"
  ##   response = @gateway.purchase(@amount, card, options)
  ##   assert_success response
  ##   assert_equal 'transaction approved', response.message
  ## end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize_declined_card
    auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth
    assert_equal 'Cartão vencido', auth.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Success', response.message
  end

  def test_successful_complete_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "abcdefg12345")
    assert_failure response
    assert_equal 'Not Found', response.message
  end

  def test_failed_capture_over_amount
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    response = @gateway.capture(@amount + 1, auth.authorization)
    assert_failure response
    assert_equal 'Invalid amount to confirm', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_failed_refund
    assert refund = @gateway.refund(@amount, "abcdef-4fab-41bd-bafb-3be7d0bf2085")
    assert_failure refund
    assert_equal 'payment_id is invalid', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Credit transaction cancelled sucessfully', void.message
  end

  def test_failed_void
    response = @gateway.void('abcdefg12345')
    assert_failure response
    assert_equal 'payment_id is invalid', response.message
  end
end
