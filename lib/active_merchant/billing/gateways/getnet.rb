require "base64"
require "json"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GetnetGateway < Gateway
      self.test_url = 'https://api-sandbox.getnet.com.br'
      self.live_url = 'https://api.getnet.com.br'

      self.default_currency = 'BRL'

      self.homepage_url = 'https://developers.getnet.com.br/'
      self.display_name = 'Getnet'
      self.money_format = :cents
      
      STANDARD_ERROR_CODE_MAPPING = {}

      ENDPOINT_MAPPING = {
        :authorize => "/v1/payments/credit",
        :confirm => "/v1/payments/credit/%s/confirm",
        :credit_payment => "/v1/payments/credit",
        :credit_void => "/v1/payments/credit/%s/cancel",
        :debit_payment => "/v1/payments/debit",
        :three_d_secure_payment => "/v1/payments/authenticated",
        :debit_void => "/v1/payments/debit/%s/cancel",
        :oauth => "/auth/oauth/v2/token",
        :refund => "/v1/payments/cancel/request",
        :tokenize => "/v1/tokens/card",
        :verify => "/v1/cards/verification",
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

        if options[:three_d_secure]
          add_payment(post, payment, options, access_token)
          add_three_d_secure(post, options)
        else
          add_customer(post, options)
          add_device(post, options)
          add_order(post, options)
          
          if options[:debit]
            add_debit(post, payment, options, access_token)
            commit(:debit_payment, post, access_token)
          else
            add_credit(post, payment, options, access_token)
            commit(:credit_payment, post, access_token)
          end
        end

      end

      def authorize(money, payment, options = {})
        access_token = acquire_access_token
        options[:pre_auth] = true
        post = {}
        add_invoice(post, money, options)
        add_order(post, options)
        add_customer(post, options)
        add_device(post, options)

        if options[:debit]
          add_debit(post, payment, options, access_token)
        else
          add_credit(post, payment, options, access_token)
        end

        commit(:authorize, post, access_token)
      end

      def capture(money, authorization, options = {})
        access_token = acquire_access_token
        post = {}
        post[:amount] = amount(money)
        options[:authorization] = authorization
        commit(:confirm, post, access_token, options)
      end

      def refund(money, authorization, options = {})
        access_token = acquire_access_token
        post = {}
        post[:cancel_amount] = amount(money)
        post[:payment_id] = authorization
        commit(:refund, post, access_token)
      end

      def void(authorization, options = {})
        access_token = acquire_access_token
        options[:authorization] = authorization
        
        if options[:debit]
          commit(:debit_void, nil, access_token, options)
        else
          commit(:credit_void, nil, access_token, options)
        end
      end

      def verify(creditcard, options = {})
        access_token = acquire_access_token
        post = build_card(creditcard, options, access_token)
        commit(:verify, post, access_token)
      end

      def supports_scrubbing?
        false
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:seller_id] = options[:seller_id] if options[:seller_id]
      end

      def add_order(post, options)
        order = {}
        order[:order_id] = options[:order_id].to_s if options[:order_id]
        order[:sales_tax] = options[:sales_tax] if options[:sales_tax]
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

      def add_three_d_secure(post, options)
        order[:order_id] = options[:order_id].to_s if options[:order_id]
        post[:xid] = three_d_secure[:xid] if three_d_secure[:xid]
        post[:ucaf] = three_d_secure[:ucaf] if three_d_secure[:ucaf]
        post[:eci] = three_d_secure[:eci] if three_d_secure[:eci]
        post[:tdsdsxid] = three_d_secure[:tdsdsxid] if three_d_secure[:tdsdsxid]
        post[:tdsver] = three_d_secure[:tdsver] if three_d_secure[:tdsver]
        payment[:payment_method] = if options[:debit] then "DEBIT" else "CREDIT" end
      end

      def add_credit(post, card, options, access_token)
        post[:credit] = {}
        add_payment post[:credit], card, options, access_token
      end

      def add_debit(post, card, options, access_token)
        post[:debit] = {}
        add_payment post[:debit], card, options, access_token
      end

      def add_payment(parent, card, options, access_token)
        parent[:card] = build_card card, options, access_token
        parent[:delayed] = false
        parent[:dynamic_mcc] = options[:dynamic_mcc] if options[:dynamic_mcc]
        parent[:number_installments] = 1
        parent[:pre_authorization] = options[:pre_auth]
        parent[:save_card_data] = false
        parent[:soft_descriptor] = options[:description] if options[:description]
        parent[:transaction_type] = "FULL"
      end

      def build_card(creditcard, options, access_token)
        card = {}
        card[:cardholder_name] = creditcard.name
        card[:expiration_month] = creditcard.month.to_s.rjust(2, '0')
        card[:expiration_year] = creditcard.year.to_s[-2...]
        card[:number_token] = options[:token] || get_card_token(creditcard, options, access_token)
        card[:security_code] = creditcard.verification_value

        if !creditcard.brand.nil?
          card[:brand] = map_card_brand(creditcard.brand)
        end
        
        card
      end
      
      def parse(body)
        body.blank? ? {} :  JSON.parse(body)
      end

      def commit(action, parameters, access_token, options={})
        url = url_from(action, options)
        headers = build_api_headers(access_token)
        
        begin
          response = parse(ssl_post(url, post_data(parameters), headers))
        rescue ResponseError => e
          response = parse(e.response.body)
        end
        success = success_from(action, response)
        Response.new(
          success,
          message_from(success, action, response),
          response,
          authorization: authorization_from(success, action, response),
          avs_result: nil,
          cvv_result: nil,
          test: test?
        )
      end

      def success_from(action, response)
        case action.to_s
        when "authorize"
          response["status"] == "AUTHORIZED"
        when "confirm"
          response["status"] == "CONFIRMED"
        when "credit_payment", "debit_payment"
          response["status"] == "APPROVED"
        when "credit_void", "debit_void"
          response["status"] == "CANCELED"
        when "refund"
          response["status"] == "ACCEPTED"
        when "verify"
          response["status"] == "VERIFIED"
        else
          false
        end
      end

      def message_from(success, action, response)
        if success
          case action.to_s
          when "credit_payment", "authorize"
            response.dig('credit', 'reason_message')
          when "confirm"
            response.dig('credit_confirm', 'message')
          when "credit_void"
            response.dig('credit_cancel', 'message')
          when "debit_void"
            response.dig('debit_cancel', 'message')
          else
            'Success'
          end
        else
          find_error_message response
        end
      end

      def find_error_message(response)
        # Sometimes Getnet passes the error as a Hash,
        # and sometimes they pass it as the first value in an array.
        if (response['details'].is_a?(Hash) and 
            response['details']['description'])
          response['details']['description']
        elsif (response['details'].is_a?(Array) and 
               response['details'].count == 1 and
               response['details'][0]['description'])
          response['details'][0]['description']
        else
          'Failed'
        end
      end

      def authorization_from(success, action, response)
        if !success
          false
        end
        
        case action.to_s
        when 'credit_payment', 'authorize', 'debit_payment', 'confirm'
            response["payment_id"]
        when 'refund'
          response['cancel_request_id']
        when 'verify'
          response['authorization_code']
        else
          nil
        end
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

      def get_card_token(creditcard, options, access_token)
        parameters = {
          :card_number => creditcard.number
        }

        headers = build_api_headers(access_token)
        
        raw_response = ssl_post(url_from(:tokenize), post_data(parameters), headers)
        response = parse(raw_response)
        response["number_token"]
      end
      
      def acquire_access_token
        data = "scope=oob&grant_type=client_credentials"
        oauth_headers = build_access_token_headers
        response = ssl_post(url_from(:oauth), data, oauth_headers)
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
          'Content-Type'	=> 'application/x-www-form-urlencoded'
        }
      end

      def build_api_headers(access_token)
        {
          "Authorization"	=> "Bearer #{access_token}",
          'Content-Type'	=> 'application/json'
        }
      end
      
      def url_from(action, options={})
        endpoint = ENDPOINT_MAPPING[action]

        case action.to_s
        when "credit_void", "debit_void", "confirm"
          endpoint = endpoint % options[:authorization]
        end
        
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

      def map_card_brand(brand)
        case brand.downcase
        when 'visa'
          'Visa'
        when 'mastercard'
          'MasterCard'
        when 'americanexpress', 'amex'
          'Amex'
        when 'elo'
          'Elo'
        when 'hipercard'
          'Hipercard'
        end
      end
    end
  end
end
