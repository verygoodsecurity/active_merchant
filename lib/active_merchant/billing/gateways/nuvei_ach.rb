# coding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NuveiAchGateway < Gateway
      self.test_url         = 'https://ppp-test.safecharge.com/ppp/api/v1/'
      self.live_url         = 'https://secure.safecharge.com/ppp/api/v1/'
      self.default_currency = 'USD'
      self.homepage_url     = 'https://www.nuvei.com/'
      self.display_name     = 'Nuvei'

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_site_id, :secret)
        @merchant_id, @merchant_site_id, @secret = options.values_at(:merchant_id, :merchant_site_id, :secret)
        super
      end

      # Creates a session token for the user
      # {
      #     "merchantId":"<your merchantId goes here>",
      #     "merchantSiteId":"<your merchantSiteId goes here>",
      #     "clientUniqueId":"<unique transaction ID in merchant system>",
      #     "clientRequestId":"<unique request ID in merchant system>",
      #     "currency":"USD",
      #     "amount":"200",
      #     "timeStamp":"<YYYYMMDDHHmmss>",
      #     "checksum":"<calculated checksum>"
      # }
      def create_order(amount, options = {})
        timestamp             = Time.now.utc.strftime("%Y%m%d%H%M%S")
        post                  = init_post
        post[:amount]         = amount(amount)
        post[:currency]       = currency(amount)
        post[:clientUniqueId] = options[:transaction_id].to_s
        post[:userTokenId]    = options[:customer_id].to_s
        add_trans_details(post, amount, options, timestamp)
        add_device_details(post, options)
        post[:checksum] = get_payment_checksum(post[:clientRequestId], post[:amount], post[:currency], timestamp)
        commit('openOrder', post, options)
      end

      private

      def get_trans_id(authorization)
        response = authorization.split('|').first()
      end

      def open_session
        timestamp  = Time.now.utc.strftime("%Y%m%d%H%M%S")
        checksum   = get_session_checksum(timestamp)
        parameters = {
          :merchantId     => @merchant_id,
          :merchantSiteId => @merchant_site_id,
          :timeStamp      => timestamp,
          :checksum       => checksum
        }

        begin
          raw_response = ssl_post(url('getSessionToken'), post_data(parameters), request_headers(options))
          response     = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response     = parse(raw_response)
        end
      end

      def get_session_checksum (timestamp)
        base = @merchant_id + @merchant_site_id + timestamp + @secret
        Digest::SHA256.hexdigest base
      end

      def add_session(post, session)
        post[:sessionToken] = session['sessionToken']
      end

      def add_device_details(post, options)
        post[:deviceDetails] = {
          :ipAddress => options[:ip]
        }
      end

      def add_billing_address(post, options)
        post[:billingAddress] = {
          :email => options[:email],
          # Country must be ISO 3166-1-alpha-2 code.
          # See: www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm
          :country => options.dig(:billing_address, :country)
        }
      end

      def get_payment_checksum (client_request_id, amount, currency, timestamp)
        base = @merchant_id + @merchant_site_id + client_request_id +
          amount.to_s + currency + timestamp + @secret
        Digest::SHA256.hexdigest base
      end

      def add_payment_option(post, payment)
        # TODO: Add support for ACH payments
        # "alternativePaymentMethod": {
        #   "paymentMethod": "apmgw_ACH",
        #   "AccountNumber": "111111111",
        #   "RoutingNumber": "999999992"
        # }
        post[:paymentOption] = {
          :alternativePaymentMethod => {
            :paymentMethod => "apmgw_Secure_Bank_Transfer"
          }
        }
      end

      def add_trans_details(post, money, options, timestamp)
        post[:amount]          = amount(money)
        post[:clientRequestId] = options[:order_id].to_s
        post[:clientUniqueId]  = options[:transaction_id].to_s
        post[:currency]        = options[:currency] || currency(money)
        post[:timeStamp]       = timestamp
      end

      def add_merchant_options(post)
        post[:merchantId]     = @merchant_id
        post[:merchantSiteId] = @merchant_site_id
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post(url(action), post_data(parameters), request_headers(options))
          response     = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response     = parse(raw_response)
        end

        success = action_from(action, response)
        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, action, response),
          test:          test?,
        )
      end

      def url(action)
        if test?
          "#{test_url}#{action}.do"
        else
          "#{live_url}#{action}.do"
        end
      end

      def request_headers(options)
        {
          'Content-Type' => 'application/json',
        }
      end

      def action_from(action, response)
        success_conditions = {
          'openOrder'         => response['status'] == "SUCCESS",
          'payment'           => response['status'] == "SUCCESS" && response['transactionStatus'] == "APPROVED",
          'payout'            => response['status'] == "SUCCESS" && response['transactionStatus'] == "APPROVED",
          'refundTransaction' => response['status'] == "SUCCESS" && response['transactionStatus'] == "APPROVED",
        }

        success_conditions[action.to_s] || false
      end

      def message_from(success, response)
        return 'Succeeded' if success
        return response['reason'] unless response['reason'].to_s.empty?
        return response['gwErrorReason'] unless response['gwErrorReason'].to_s.empty?
        'Failed'
      end

      def authorization_from(success, action, response)
        if !success
          nil
        elsif action == "payment"
          # If a userPaymentOptionId exists, then the payment authorizations
          # will be in the format: {transactionId}|{userPaymentOptionId}
          # The userPaymentOptionId is required for posting credit to this
          # card in the future. This value is blank if userTokenId is blank when
          # posting the payment.
          authorization = response['transactionId'].to_s
          upo_id        = response.dig('paymentOption', 'userPaymentOptionId')
          if !upo_id.blank?
            authorization += "|" + upo_id
          end

        elsif !response['transactionId'].nil?
          authorization = response['transactionId'].to_s
        else
          authorization = response["internalRequestId"].to_s
        end

        authorization
      end

      def init_post(options = {})
        post = {}
        add_merchant_options(post)
        post
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end
    end
  end
end
