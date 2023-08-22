require 'test_helper'
require 'securerandom'

class RemoteNuveiAchTest < Test::Unit::TestCase
  def setup
    @example_request = {
      "amount":          "100",
      "billingAddress":  {
        "address":   "22 Main Street",
        "city":      "Boston",
        "country":   "US",
        "email":     "john.smith@email.com",
        "firstName": "John",
        "lastName":  "Smith",
        "phone":     "6175551414",
        "state":     "MA",
        "zip":       "02460"
      },
      "checksum":        "<calculated checksum>",
      "clientRequestId": "<unique request ID in merchant system>",
      "clientUniqueId":  "<unique transaction ID in merchant system>",
      "currency":        "USD",
      "deviceDetails":   {
        "ipAddress": "<customer's IP address>"
      },
      "merchantId":      "<your merchantId>",
      "merchantSiteId":  "<your merchantSiteId>",
      "paymentOption":   {
        "alternativePaymentMethod": {
          "paymentMethod": "apmgw_Secure_Bank_Transfer"
        }
      },
      "sessionToken":    "<sessionToken from getSessionToken>",
      "timeStamp":       "<YYYYMMDDHHmmss>",
      "urlDetails":      {
        "notificationUrl": "[URL to which DMNs are sent]"
      },
      "userDetails":     {
        "firstName":      "John",
        "lastName":       "Smith",
        "email":          "john.smith@email.com",
        "phone":          "6175551414",
        "address":        "22 Main Street",
        "city":           "Boston",
        "zip":            "02460",
        "state":          "MA",
        "country":        "US",
        "identification": "123456789"
      },
      "userTokenId":     "<unique customer identifier in merchant system>"
    }
    # Transform keys in @example_request to symbols and snake_case
    # Sort keys in @example_request
    @example_request = @example_request.deep_transform_keys { |key| key.to_s.underscore.to_sym }.sort.to_h

    # Generate @user_details from @example_request
    @user_details = @example_request[:user_details].slice(:first_name, :last_name, :email, :phone, :address, :city, :zip, :state, :country, :identification)

    # Generate @billing_address from @example_request
    @billing_address = @example_request[:billing_address].slice(:first_name, :last_name, :email, :phone, :address, :city, :zip, :state, :country)

    # Generate @device_details from @example_request
    @device_details = @example_request[:device_details].slice(:ip_address)

    @gateway = NuveiAchGateway.new(fixtures(:nuvei_ach))
    @amount  = 125
    @check   = check(account_number: '111111111', routing_number: '123456780')
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
    @options = {
      order_id:        1,
      billing_address: address,
      description:     'Fake purchase',
      ip:              '127.0.0.1',
      email:           'test@test.com'
    }

    # example successful response:
    @example_successful_response = {
      "clientRequestId":   "GF1XTXTBM",
      "clientUniqueId":    "695701003",
      "errCode":           0,
      "internalRequestId": 17817111,
      "merchantId":        "2502136204546424962",
      "merchantSiteId":    "126006",
      "orderId":           "36298881",
      "paymentOption":     {
        "redirectUrl":         "https://cdn-int.safecharge.com/safecharge_resources/v1/get_to_post/index.html?eyJhbGciOiJSUzI1NiJ9.eyJkZXRhaWxzIjoiNzRDQkZEODMyOUI1RDMwMjNDM0YwNUJERThGRkFEMDRGQUNEMURCQUZFMEYxM0QwMzhFQkU5RjRCMzhFMTY2RTY5NEI0QzhDMDg2RjYzMDM2RTdCMkIyREVBRjRENTIyNkM2RDg1RUE5NkI2QjIzNjEzMUVBREI0NDBGRjU0QzE0RThGM0ZCODg2QzUwQzcyMTYxMURBMkNBQzg1NzI2NjRCOEE4ODE0MThEMkJCMjBFNTAzRDE4MTRBMkJBM0M1NjM3RDBCNkFFRDU5MUVFQzk2NEQwMUE2OEFFRUQyMDBBMUJBRUQ4RUIxNDBGNEEwQkQ2OTE3MzYxMEM4Rjg1MTAwMjMxREEzQkRDNUZGMkNGOUNGRURCQkZFMTQ2REEwMDdCQUY4QUUzN0Q1Q0JEQTYzOTQyNDhGMkFEQzhFMzMyODU4NzQ5MzUyNTI2NDFFREREM0Q4ODEwQTE3RkVCNTlBMjY4ODBCMkI2NjYzRkVENjk3RjRBMDhERTFBNzVDRDdBMzk2MzBGRjJBREU1Mjk0N0FERjFFQUVFMDA4Nzg4Q0REN0RCNjM5M0QwRTNEOTFBQkVERTY3MDFBMUQ0RkU3M0M3RTQwNUQ5RjlCNzZDMUYxRjQ5QzIxMjU4RERENDVDQUFDNTNERDg4MEVBNTk2Mzk1QzBDRDQ4NUY0OTQ4M0VERURGNDJFRkQzMUJBNkIwMUYwMTFGMTVGNzAyMUI2OTRBOUQ1NTU0OEEyQ0FDNUQ3MzVBNTgyMkJCMEFDOUFCQjhBQzc1Q0UxNzc1NjI0QzY1QUQ1MDU4NTVCRDI5RjFCMjJCMDlCREExM0I1QkFFQ0ZEMTA1MUI2NTQ4QTUxQkJDNDlEOTlCQUI4MUZERjAwNzAyQTBDQ0IyQTk3MDVENzE2MkZFRUQ5RjEzN0ZGN0FGMDUwNUIyMUIwOTY2RDA2NTFFQkRDRDA1MkY0RTE4MDY5ODlCOEFBQjJDMTIxNkIzNzJDREQ5RDQ0RDQ2N0EwOEUwQjI4MkUzOTkwNjAwOTcyQ0NDNEYwQjZEMDdERDg1ODk2MDYzM0UwNkExQ0VGRTY0OEExNzBDOTA3RjA3Qzg4NDA4NDI0MzQzRjNGQjM1MDZFN0EzRkEwNkQ0MDY5M0QyQkE3MzBGQTdCNzc3NDFFQUU2NDg2NEI2NjE3MDdGMzY0MDNCMTQyOTJDMTM1NzI5NDUwQ0YxRDk3NTcxQUE5NzJDQzg1MTVGQSIsIm1lcmNoYW50X2lkIjoiU2ZDaGFyZ2UiLCJpdiI6Ijk5RTM0MEMyNzg0MkNBOTlCQkIxQzUyNzVFQUFFNURBIiwidXJsIjoiaHR0cHM6Ly9zdGFnaW5nLnZlcmlmaWVkYWNoLmNvbS9jb25zdW1lci9BY3F1aXJlSW5mb0dhdGV3YXkuZG8ifQ.EF3K5UsPQYdua_YcRd9Yefl-KemNwEMq5-EXV7QWAZUbCQglncAaAHzzlW-sxq2XcVZcZ2qbxLkQqjzkB3tItTGUDmqysL-opqOdaaz54EKeHKC5hzQIp77DucIGYQhPxfOB_eAxTOPLvZ85c3woJ37m8BH8kuJPSoAjYrZ12geEQJQx4R2VxNT3QsxxryEWZvU1yKc8mjCl011nWz6cp4LZpHIMwUwvdCMJWUeJtAxC-Q6Ec4NqP93AFki9Ln0OOvenbOEBn3UpK_BncxKu7RFOzM8w4kSf0eopKC44awlROwZaO0k0htJAUikA_W-fgeLISuMpHmWMZz6X3Ju2Bg",
        "userPaymentOptionId": "8061731",
        "card":                {}
      },
      "reason":            "",
      "sessionToken":      "6fa38ea2-6f1a-4620-85ae-7deaf0d5f8f1",
      "status":            "SUCCESS",
      "transactionStatus": "REDIRECT",
      "userTokenId":       "2J6QZH3UF9E2",
      "version":           "1.0"
    }.deep_stringify_keys(&:to_sym)
  end

  def test_successful_purchase
    options                  = @options.dup
    options[:order_id]       = generate_unique_id
    options[:user_token_id]  = generate_unique_id
    options[:transaction_id] = generate_unique_id
    response                 = @gateway.purchase(@amount, @check, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    # Ensure that the authorization has a pipe to separate transactionId and user_payment_option_id
    assert response.authorization.include? "|"
  end

end

