require 'test_helper'

class GetnetTest < Test::Unit::TestCase
  def setup
    @gateway = GetnetGateway.new(
      username: 'username',
      password: 'password',
      test: true)
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
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)

    response = @gateway.send(:acquire_access_token)
    
    assert_equal response, "abc12345-6c4d-4d92-9f3f-81385966693f"
  end
  
  def test_failure_acquire_access_token
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(failure_oauth_access_token)
    assert_raise Error do
      response = @gateway.send(:acquire_access_token)
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/payments/credit', anything, anything)
      .returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '0533533f-0e8d-4478-af9f-39ce0d388443', response.authorization
    assert response.test?
  end

  def test_add_three_d_secure()
    options = {
      :order_id => "12345",
      :token => "abcdefghijklmnop",
      :three_d_secure => {
        :xid => "XIDstringstringstringstringstringstri",
        :ucaf => "UCAFstringstringstringstringstringstri",
        :eci => "st",
        :tdsdsxid => "dbdcb82d-63c5-496f-ae27-1ecfc3a8dbec",
        :tdsver => "2.1.0"
      }
    }
    post = {}
    card_obj = @gateway.send(:add_three_d_secure, post, options)

    three_d_secure = options[:three_d_secure]
    assert_equal post[:xid], three_d_secure[:xid]
    assert_equal post[:ucaf], three_d_secure[:ucaf]
    assert_equal post[:eci], three_d_secure[:eci]
    assert_equal post[:tdsdsxid], three_d_secure[:tdsdsxid]
    assert_equal post[:tdsver], three_d_secure[:tdsver]
    assert_equal post[:payment_method], "CREDIT"
  end

  def test_add_three_d_secure_debit()
    options = {
      :debit => true,
      :order_id => "12345",
      :token => "abcdefghijklmnop",
      :three_d_secure => {
        :xid => "XIDstringstringstringstringstringstri",
        :ucaf => "UCAFstringstringstringstringstringstri",
        :eci => "st",
        :tdsdsxid => "dbdcb82d-63c5-496f-ae27-1ecfc3a8dbec",
        :tdsver => "2.1.0"
      }
    }
    post = {}
    card_obj = @gateway.send(:add_three_d_secure, post, options)

    three_d_secure = options[:three_d_secure]
    assert_equal post[:xid], three_d_secure[:xid]
    assert_equal post[:ucaf], three_d_secure[:ucaf]
    assert_equal post[:eci], three_d_secure[:eci]
    assert_equal post[:tdsdsxid], three_d_secure[:tdsdsxid]
    assert_equal post[:tdsver], three_d_secure[:tdsver]
    assert_equal post[:payment_method], "DEBIT"
  end

  def test_add_three_d_secure_missing_data()
    options = {
      :order_id => "12345",
      :token => "abcdefghijklmnop",
      :three_d_secure => {
      }
    }
    post = {}
    card_obj = @gateway.send(:add_three_d_secure, post, options)

    three_d_secure = options[:three_d_secure]
    assert_equal post[:xid], nil
    assert_equal post[:ucaf], nil
    assert_equal post[:eci], nil
    assert_equal post[:tdsdsxid], nil
    assert_equal post[:tdsver], nil
    assert_equal post[:payment_method], "CREDIT"
  end

  def test_successful_3ds_purchase
    # Pass in the following options:
    options = {
      order_id: 1,
      three_d_secure: {
        xid: "stringstringstringstringstringstringstri",
        ucaf: "stringstringstringstringstringstringstri",
        eci: "st",
        tdsdsxid: "dbdcb82d-63c5-496f-ae27-1ecfc3a8dbec",
        tdsver: "2.1.0"
      },
      token: "abcdefghijklmnop"
    }

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/payments/authenticated', anything, anything)
      .returns(successful_purchase_response_3ds)

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response

    assert_equal '123456c8-1bbf-42bf-93b4-ce2041bfb87e', response.authorization
    assert_equal response.message, "transaction approved"
    assert response.test?
  end

  # Ensure that if we do not pass a otken, we make a request for one and apply it to the card object correctly
  def test_build_card_obj_no_token
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    card_obj = @gateway.send(:build_card, @credit_card, @options, "12345")
    assert_equal card_obj[:number_token], "1ca7f5bac9bf3ad9609cab46d3b99770fc4d64a9edd231b74dc36c7ae0f37f5f5b5684d1281bb5bb4d3a9c838cbeb6c83c1858a1b882d2691563ee291bdasdf"
  end

  # Ensure that if we pass a token, it is used as the card
  def test_build_card_obj_with_token
    options = @options.dup
    options[:token] = "ABCDEF"
    card_obj = @gateway.send(:build_card, @credit_card, options, "12345")
    assert_equal card_obj[:number_token], "ABCDEF"
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/payments/credit', anything, anything)
      .returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Cartão vencido"
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/payments/credit', anything, anything)
      .returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'abcdef-4fab-41bd-bafb-3be7d0bf2085', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/payments/credit', anything, anything)
      .returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Cartão vencido"
  end

  def test_successful_verify
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
 
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/cards/verification', anything, anything)
      .returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
 
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/tokens/card', anything, anything)
      .returns(successful_get_card_token_response)

    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/v1/cards/verification', anything, anything)
      .returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal response.message, "Error message"
    assert response.test?
  end

  def test_successful_capture
    pre_auth = 'abcdef-4fab-41bd-bafb-3be7d0bf2085'
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/credit/#{pre_auth}/confirm", anything, anything)
      .returns(successful_capture_response)

    response = @gateway.capture(@amount, pre_auth, @options)

    assert_success response
    assert_equal 'Preauthorized abcdefeb-4849-4328-a2c9-63000204db8b confirmed', response.message
    assert_equal 'abcdefeb-4849-4328-a2c9-63000204db8b', response.authorization
    assert response.test?
  end

  def test_successful_capture_3ds
    pre_auth = 'abcdef-4fab-41bd-bafb-3be7d0bf2085'
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/authenticated/#{pre_auth}/confirm", anything, anything)
      .returns(successful_capture_response_3ds)

    options = {
      :three_d_secure => {
        :payment_method => "CREDIT_PRE_AUTHORIZATION"
      }
    }
    response = @gateway.capture(@amount, pre_auth, options)

    assert_success response
    assert_equal 'transaction approved', response.message
    assert_equal '12340b07-6e37-4bd9-a37b-99156cb34104', response.authorization
    assert response.test?
  end

  def test_failed_capture
    pre_auth = 'abcdef-4fab-41bd-bafb-3be7d0bf2085'
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/credit/#{pre_auth}/confirm", anything, anything)
      .returns(failed_capture_response)

    response = @gateway.capture(@amount, pre_auth, @options)

    assert_failure response
    assert_equal 'Bad Request', response.message
    assert response.test?
  end

  def test_successful_refund
    payment_id = 'abcdef-4fab-41bd-bafb-3be7d0bf2085'
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/cancel/request", anything, anything)
      .returns(successful_refund_response)

    response = @gateway.refund(@amount, payment_id, @options)

    assert_success response
    assert_equal 'Success', response.message
    assert_equal '123468385637229683', response.authorization
    assert response.test?
  end

  def test_failed_refund
    payment_id = 'abcdef-4fab-41bd-bafb-3be7d0bf2085'
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/cancel/request", anything, anything)
      .returns(failed_refund_response)

    response = @gateway.refund(@amount, payment_id, @options)

    assert_failure response
    assert_equal 'payment_id is invalid', response.message
    assert response.test?
  end

  def test_successful_void
    payment_id = "abcdef84-9113-415e-aeea-ee63fe999a90"
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/credit/#{payment_id}/cancel", anything, anything)
      .returns(successful_void_response)

    response = @gateway.void(payment_id)

    assert_success response
    assert_equal 'Credit transaction cancelled sucessfully', response.message
    assert response.test?
  end

  def test_successful_void_3ds
    payment_id = "abcdef84-9113-415e-aeea-ee63fe999a90"
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/authenticated/#{payment_id}/cancel", anything, anything)
      .returns(successful_void_response_3ds)

    options = {
      :three_d_secure => {
        :payment_method => "CREDIT"
      }
    }

    response = @gateway.void(payment_id, options)

    assert_success response
    assert_equal 'transaction approved 3DS TEST', response.message
    assert response.test?
  end

  def test_failed_void
    payment_id = "abcdef84-9113-415e-aeea-ee63fe999a90"
    @gateway.expects(:ssl_post)
      .with('https://api-homologacao.getnet.com.br/auth/oauth/v2/token', anything, anything)
      .returns(successful_oauth_access_token)
    
    @gateway.expects(:ssl_post)
      .with("https://api-homologacao.getnet.com.br/v1/payments/credit/#{payment_id}/cancel", anything, anything)
      .returns(failed_void_response)

    response = @gateway.void(payment_id)

    assert_failure response
    assert_equal 'payment_id is invalid', response.message
    assert response.test?
  end


  def successful_get_card_token_response
    %({"number_token":"1ca7f5bac9bf3ad9609cab46d3b99770fc4d64a9edd231b74dc36c7ae0f37f5f5b5684d1281bb5bb4d3a9c838cbeb6c83c1858a1b882d2691563ee291bdasdf"})
  end
  
  def successful_purchase_response
    %(
    {
        "payment_id": "0533533f-0e8d-4478-af9f-39ce0d388443",
        "seller_id": "ffd0e6de-86c7-43c9-8675-209360f29833",
        "amount": 100,
        "currency": "BRL",
        "order_id": "1",
        "status": "APPROVED",
        "received_at": "2022-05-20T18:48:17.469Z",
        "credit": {
            "delayed": false,
            "authorization_code": "677027417712",
            "authorized_at": "2022-05-20T18:48:17.469Z",
            "reason_code": "0",
            "reason_message": "transaction approved",
            "acquirer": "GETNET",
            "soft_descriptor": "EC*SANDBOX",
            "terminal_nsu": "198989",
            "brand": "Visa",
            "acquirer_transaction_id": "20222726",
            "transaction_id": "5149134883273674",
            "first_installment_amount": "100",
            "other_installment_amount": "100",
            "total_installment_amount": "100"
        }
    }
    )
  end

  def failed_purchase_response
    %({
         "message": "Erro ao efetuar a autorização de crédito",
         "name": "CreditServiceError",
         "status_code": 402,
         "details": [
         {
            "status": "NOT APPROVED",
            "error_code": "PAYMENTS-003",
            "description": "Cartão vencido",
            "description_detail": "CARTAO VENCIDO [ECOM - 54]"
         }]
       }
    )
  end

  def successful_purchase_response_3ds
    %({
      "payment_id": "123456c8-1bbf-42bf-93b4-ce2041bfb87e",
      "seller_id": "1234512c-165a-41cd-b1d9-76c575d70a28",
      "amount": 100,
      "currency": "BRL",
      "order_id": "123345380-d8a3-4ccb-9138-c289182818a3",
      "status": "APPROVED",
      "payment_method": "string",
      "received_at": "2017-03-19T16:30:30.764Z",
      "transaction_id": "string",
      "original_transaction_id": "string",
      "authorized_at": "2017-03-19T16:30:30Z",
      "reason_code": 0,
      "reason_message": "transaction approved",
      "acquirer": "GETNET",
      "soft_descriptor": "Descrição para fatura",
      "brand": "Mastercard",
      "authorization_code": "6964722471672911",
      "acquirer_transaction_id": "160453221",
      "eci": "st",
      "ucaf": "stringstringstringstringstringstringstri",
      "xid": "stringstringstringstringstringstringstri",
      "total_installment_amount": 50,
      "first_installment_amount": 50,
      "other_installment_amount": 50
    })
  end
  def successful_authorize_response
    %(
    {
        "payment_id": "abcdef-4fab-41bd-bafb-3be7d0bf2085",
        "seller_id": "abcdef-86c7-43c9-8675-209360f29833",
        "amount": 100,
        "currency": "BRL",
        "order_id": "1",
        "status": "AUTHORIZED",
        "received_at": "2022-05-20T19:38:54.339Z",
        "credit": {
            "delayed": false,
            "authorization_code": "337620720341",
            "authorized_at": "2022-05-20T19:38:54.339Z",
            "reason_code": "0",
            "reason_message": "transaction approved",
            "acquirer": "GETNET",
            "soft_descriptor": "EC*SANDBOX",
            "terminal_nsu": "803910",
            "brand": "Visa",
            "acquirer_transaction_id": "8649505",
            "transaction_id": "6973873151771555"
        }
    }
    )
  end

  def failed_authorize_response
    %({
        "message": "Erro ao efetuar a autorização de crédito",
        "name": "CreditServiceError",
        "status_code": 402,
        "details": [
            {
                "status": "NOT APPROVED",
                "error_code": "PAYMENTS-003",
                "description": "Cartão vencido",
                "description_detail": "CARTAO VENCIDO [ECOM - 54]"
            }
        ]
    }
    )
  end

  def successful_verify_response
    %(
    {
        "status": "VERIFIED",
        "verification_id": "2bab27ea-9821-41b9-89f5-d706b922dfd3",
        "authorization_code": "840476948988298000"
    }
    )
  end
  
  def failed_verify_response
    %(
    {
      "message": "string",
      "name": "string",
      "status_code": 0,
      "details": [
          {
              "description": "Error message"
          }
      ]
    }
    )
  end
  
  def successful_capture_response
    %(
    {
        "payment_id": "abcdefeb-4849-4328-a2c9-63000204db8b",
        "seller_id": "abcdefde-86c7-43c9-8675-209360f29833",
        "amount": 100,
        "currency": "BRL",
        "order_id": "1",
        "status": "CONFIRMED",
        "credit_confirm": {
            "confirm_date": "2022-05-20T21:48:28.540Z",
            "message": "Preauthorized abcdefeb-4849-4328-a2c9-63000204db8b confirmed"
        }
    }
    )
  end

  def successful_capture_response_3ds
    %({
        "payment_id" : "12340b07-6e37-4bd9-a37b-99156cb34104" ,
        "seller_id" : "12340ea0-b7d1-42f5-ad78-5a5521e3125f" ,
        "amount" : 200000 ,
        "currency" : "BRL" ,
        "order_id" : "12344380-d8a3-4ccb-9138-c289182818a3" ,
        "status" : "CONFIRMED" ,
        "confirmed_at" : "string" ,
        "reason_code" : 0 ,
        "reason_message" : "transaction approved"
    })
  end

  def failed_capture_response
    %(
    {
        "message": "Bad Request",
        "name": "PaymentNotFound",
        "status_code": 400,
        "details": [
            {
                "status": "DENIED",
                "error_code": "PAYMENTS-400",
                "description": "Bad Request",
                "description_detail": "Transaction not found for this payment_id."
            }
        ]
    }
    )
  end

  def successful_refund_response
    %(
    {
        "seller_id": "abcdefde-86c7-43c9-8675-209360f29833",
        "payment_id": "abcdef96-cdaa-4260-978e-1f20d2b35e10",
        "cancel_request_at": "2022-05-20T22:11:48.163Z",
        "cancel_request_id": "123468385637229683",
        "cancel_custom_key": null,
        "status": "ACCEPTED"
    }
    )
  end

  def failed_refund_response
    %(
    {
        "status_code": 400,
        "name": "ValidationError",
        "message": "Bad Request",
        "details": [
            {
                "status": "DENIED",
                "error_code": "GENERIC-400",
                "description": "payment_id is invalid",
                "description_detail": "\\"payment_id\\" length must be at least 36 characters long"
            }
        ]
    }
    )
  end

  def successful_void_response
    %(
    {
        "payment_id": "abcdef84-9113-415e-aeea-ee63fe999a90",
        "seller_id": "abcdefde-86c7-43c9-8675-209360f29833",
        "amount": 100,
        "currency": "BRL",
        "order_id": "1",
        "status": "CANCELED",
        "credit_cancel": {
            "canceled_at": "2022-05-20T22:19:14.535Z",
            "message": "Credit transaction cancelled sucessfully"
        }
    }
    )
  end

  def successful_void_response_3ds
    %(
    {
        "payment_id" : "12344da1-0753-4dcf-ac92-48721d2ff553" ,
        "seller_id" : "12340ea0-b7d1-42f5-ad78-5a5521e3125f" ,
        "amount" : 500000 ,
        "currency" : "BRL" ,
        "order_id" : "12344380-d8a3-4ccb-9138-c289182818a3" ,
        "status" : "CANCELED" ,
        "canceled_at" : "2018-07-22T18:47:32.270Z" ,
        "reason_code" : 0 ,
        "reason_message" : "transaction approved 3DS TEST"
    }
    )
  end

  def failed_void_response
    %(
    {
        "status_code": 400,
        "name": "InvalidParameter",
        "message": "Bad Request",
        "details": [
            {
                "status": "DENIED",
                "error_code": "GENERIC-400",
                "description": "payment_id is invalid",
                "description_detail": "\\"payment_id\\" length must be at least 36 characters long"
            }
        ]
    }
    )
  end

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
