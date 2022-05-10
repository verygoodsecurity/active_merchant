require "base64"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GetnetGateway < Gateway
      self.test_url = 'https://api-sandbox.getnet.com.br'
      self.live_url = 'https://api.getnet.com.br'

      self.default_currency = 'BRL'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://developers.getnet.com.br/'
      self.display_name = 'Getnet'
      self.money_format = :cents
      
      STANDARD_ERROR_CODE_MAPPING = {}

      ENDPOINT_MAPPING = {
        :oauth => "/auth/oauth/v2/token",
        :credit_payment => "/v1/payments/credit",
        :tokenize => "/v1/tokens/card"
      }

      def initialize(options = {})
        requires!(options, :username, :password)
        @username, @password = options.values_at(:username, :password)
        super
      end

      def purchase(money, payment, options = {})
        access_token = acquire_access_token

        post = {}
        add_invoice(post, money, options)
        add_order(post, options)
        add_customer(post, options)
        add_device(post, options)
        add_credit(post, payment, options, access_token)

        commit(:credit_payment, post, access_token)
      end

      def authorize(money, payment, options = {})
        access_token = acquire_access_token
        post = {}
        add_invoice(post, money, options)
        add_customer(post, options)
        add_device(post, options)
        add_credit(post, payment, options, access_token)

        commit(:authonly, post, access_token)
      end

      def capture(money, authorization, options = {})
        access_token = acquire_access_token
        commit(:capture, post, access_token)
      end

      def refund(money, authorization, options = {})
        access_token = acquire_access_token
        commit(:refund, post, access_token)
      end

      def void(authorization, options = {})
        access_token = acquire_access_token
        commit(:void, post, access_token)
      end

      def verify(credit_card, options = {})
        access_token = acquire_access_token
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_address(post, creditcard, options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:seller_id] = options[:seller_id] if options[:seller_id]
      end

      def add_order(post, options)
        order = {}
        order[:order_id] = options[:order_id].to_s if options[:order_id]
        order[:product_type] = options[:product_type] if options[:product_type]
        post[:order] = order
      end

      def add_customer(post, options)
        address = options[:billing_address] || options[:address]
        billing_address = {}
        billing_address[:street] = parse_street(address)
        billing_address[:number] = parse_house_number(address)
        billing_address[:complement] = address[:complement] if address[:complement]
        billing_address[:city] = address[:city] if address[:city]
        billing_address[:state] = address[:state] if address[:state]
        billing_address[:country] = address[:country] if address[:country]
        billing_address[:postal_code] = address[:zip] if address[:zip]

        post[:customer] = {
          :customer_id => options[:customer_id],
          :billing_address => billing_address
        }
      end

      def add_device(post, options)
        device = {}
        device[:ip_address] = options[:ip] if options[:ip]
        device[:device_id] = options[:device_id] if options[:device_id]
        post[:device] = device
      end

      def add_credit(post, creditcard, options, access_token)
        credit = {}
        credit[:delayed] = false
        credit[:dynamic_mcc] = options[:dynamic_mcc] if options[:dynamic_mcc]
        credit[:number_installments] = 1
        credit[:pre_authorization] = false
        credit[:save_card_data] = false
        credit[:soft_descriptor] = options[:description] if options[:description]
        credit[:transaction_type] = "FULL"

        card = {}
        card[:cardholder_name] = creditcard.name
        card[:expiration_month] = creditcard.month.to_s.rjust(2, '0')
        card[:expiration_year] = creditcard.year.to_s[-2...]
        card[:number_token] = options[:token] || get_card_token(creditcard, options, access_token)
        card[:security_code] = creditcard.verification_value

        credit[:card] = card
      
        post[:credit] = credit
      end

      def parse(body)
        body.blank? ? {} :  JSON.parse(body)
      end

      def commit(action, parameters, access_token)
        url = url(action)
        headers = build_api_headers(access_token)
        
        response = parse(ssl_post(url, post_data(parameters), headers))
        success = success_from(action, response)
        Response.new(
          success,
          message_from(success, action, response),
          response,
          authorization: authorization_from(success, action, response),
          avs_result: nil,
          cvv_result: nil,
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def success_from(action, response)
        case action.to_s
        when 'credit_payment'
          response["status"] == "APPROVED"
        else
          false
        end
      end

      def message_from(success, action, response)
        case action.to_s
        when 'credit_payment'
          if success
            response.dig('credit', 'reason_message')
          elsif response.dig('details', 'description')
            response.dig('details', 'description')
          else
            'Failed'
          end
        else
          false
        end
      end

      def authorization_from(success, action, response)
        case action.to_s
        when 'credit_payment'
          if success
            response["payment_id"]
          end
        else
          false
        end
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          # TODO: lookup error code for this response
        end
      end

      def get_card_token(creditcard, options, access_token)
        parameters = {
          :card_number => creditcard.number
        }

        headers = build_api_headers(access_token)
        
        raw_response = ssl_post(url(:tokenize), post_data(parameters), headers)
        response = parse(raw_response)
        response["number_token"]
      end
      
      def acquire_access_token
        data = "scope=oob&grant_type=client_credentials"
        oauth_headers = build_access_token_headers
        response = ssl_post(url(:oauth), data, oauth_headers)
        json_response = JSON.parse(response)
        if !json_response['access_token'].nil?
          json_response['access_token']
        else
          raise Error, "Unable to authenticate with GetNet"
        end
      end
      
      def build_access_token_headers
        auth_str = @username + ":" + @password
        creds_b64 = Base64.strict_encode64(auth_str)
        return {
          'Accept'		=> '*/*',
          'Authorization'	=> "Basic #{creds_b64}",
          'content-type'	=> 'application/x-www-form-urlencoded'
        }
      end

      def build_api_headers(access_token)
        {
          "Authorization"	=> "Bearer #{access_token}",
          'Content-Type'	=> 'application/json',
          # TODO: only if it is test
          "api_mode"		=> "mocked"
        }
      end
      
      def url(action)
        endpoint = ENDPOINT_MAPPING[action]
        if test?
          "#{test_url}#{endpoint}"
        else
          "#{live_url}#{endpoint}"
        end
      end

      def parse_street(address)
        address_to_parse = "#{address[:address1]} #{address[:address2]}"
        street = address[:street] || address_to_parse.split(/\s+/).keep_if { |x| x !~ /\d/ }.join(' ')
        street.empty? ? 'Not Provided' : street
      end

      def parse_house_number(address)
        address_to_parse = "#{address[:address1]} #{address[:address2]}"
        house = address[:houseNumberOrName] || address_to_parse.split(/\s+/).keep_if { |x| x =~ /\d/ }.join(' ')
        house.empty? ? 'Not Provided' : house
      end
    end
  end
end
