module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagaditoGateway < Gateway
      self.test_url = 'https://sandbox-api.pagadito.com/v1/'
      self.live_url = 'https://api.pagadito.com/v1/'
      self.default_currency = 'USD'

      self.homepage_url = 'https://www.pagadito.com/'
      self.display_name = 'Pagadito'

      def initialize(options = {})
        requires!(options, :username, :wsk)
        @username, @wsk = options.values_at(:username, :wsk)
        super
      end

      def purchase(money, payment, options = {})
        # MultiResponse.run() do |r|
        #   r.process {  }
        # end
        # post = {}
        
        # add_card(post, payment, options)
        
        # commit('payment', post)

        tokenize(money, payment, options)
        charge(money, payment, options)
      end

      private

      def tokenize(amount, creditcard, options)
        action = 'customer'
        
        post = {}
        add_card(post, options, creditcard)
        add_transaction(post, options, amount)
        add_browser_info(post, options)
        
        commit(action, post)
      end

      def charge(amount, authorization, options)
        action = 'charge'

        post = {}
        add_reference(post, authorization, options)
        add_invoice(action, post, amount, options)
        add_contact_details(post, options[:contact_details]) if options[:contact_details]
        add_full_response(post, options)
        add_metadata(post, options)

        commit(action, post)
      end

      def add_card(post, options, creditcard)
        card = {}

        card[:number] = creditcard.number
        card[:expirationDate] = "#{creditcard.month.to_s.rjust(2, '0')}/#{creditcard.year}"
        card[:cvv] = creditcard.verification_value
        card[:email] = options[:email] if options[:email]
        add_card_name(card, creditcard)
        add_billing_address(card, options)
        
        post[:card] = card
      end

      def add_card_name(card, creditcard)
        if !creditcard.name.nil?
          card[:cardHolderName] = creditcard.name
          card[:name] = creditcard.name
          name_split = creditcard.name.split(' ', 2)
          card[:firstName] = name_split[0]
          card[:lastName] = name_split[1]
        else
          card[:first_name] = creditcard.first_name if creditcard.first_name
          card[:last_name] = creditcard.last_name if creditcard.last_name
          card[:name] = creditcard.first_name + " " + creditcard.last_name
        end
      end
      
      def add_billing_address(parent, options)
        billing_address = {}

        if (address = options[:billing_address])
          billing_address[:city] = address[:city] if address[:city]
          billing_address[:state] = address[:state] if address[:state]
          billing_address[:zip] = address[:zip] if address[:zip]
          billing_address[:countryId] = country_code(address[:country]) if address[:country]
          billing_address[:line1] = address[:address1]
          billing_address[:phone] = address[:phone]
        end

        parent[:billingAddress] = billing_address
      end

      def add_transaction(post, options, amount)
        transaction = {}
        transaction[:merchantTransactionId] = options[:order_id].to_s if options[:order_id]
        transaction[:currencyId] = (options[:currency] || currency(amount))
        transaction[:transactionDetails] = [{
          :quantity => 1,
          :description => (options[:description] if options[:description]),
          :amount => amount,
        }]
        post[:transaction] = transaction
      end
      
      def country_code(country)
        if country
          country = ActiveMerchant::Country.find(country)
          country.code(:numeric).value
        end
      rescue InvalidCountryCodeError
      end

      def add_browser_info(post, options)
        browser_info = {}
        browser_info[:customerIp] = options[:ip] if options[:ip]
        browser_info[:deviceFingerprintID] = options[:device_id] if options[:device_id]
        post[:browserInfo] = browser_info
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action

        headers = build_headers
        puts "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        puts headers
        response = parse(ssl_post(url, post_data(parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def parse(body)
        body.blank? ? {} :  JSON.parse(body)
      end

      def success_from(response); end

      def message_from(response); end

      def authorization_from(response); end

      def build_headers
        auth_str = @username + ":" + @wsk
        creds_b64 = Base64.strict_encode64(auth_str)
        return {
          'Authorization'	=> "Basic #{creds_b64}",
          # 'Authorization'	=> "Basic #{auth_str}",
          'Content-Type'	=> 'application/json'
        }
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
