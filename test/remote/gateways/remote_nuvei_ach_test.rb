require 'test_helper'
require 'securerandom'

class RemoteNuveiAchTest < Test::Unit::TestCase
  def setup
    # Declined Deposit and Declined Pre-approval
    #
    # NSF – Amount 1.27
    # Declined – Amount 1.30
    # Account No: 3666394279
    # Routing No: 123456780
    # Successful Deposit and Successful Pre-approval
    #
    # Success – Amount: 1.25
    # Account No: 111111111
    # Routing No: 123456780
    @gateway = NuveiAchGateway.new(fixtures(:nuvei_ach))
    @amount = 125
    @check = check(account_number: '111111111', routing_number: '123456780')
    @options = {
      order_id: 1,
      billing_address: address,
      description: 'Fake purchase',
      ip: '127.0.0.1',
      email: 'test@test.com'
    }
  end

  def test_successful_purchase
    options = @options.dup
    options[:order_id] = generate_unique_id
    options[:user_token_id] = generate_unique_id
    response = @gateway.purchase(@amount, @check, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    # Ensure that the authorization has a pipe to separate transactionId and user_payment_option_id
    assert response.authorization.include? "|"
  end

end
