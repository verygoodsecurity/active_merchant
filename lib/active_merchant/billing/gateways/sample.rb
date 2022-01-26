module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SampleGateway < Gateway
      self.test_url = 'https://echo.apps.verygood.systems/post'
      self.live_url = 'https://echo.apps.verygood.systems/post'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.verygoodsecurity.com//'
      self.display_name = 'VGS sample gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
      end

      def void(authorization, options = {})
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        false
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
        ;
      end

      def add_address(post, creditcard, options)
        ;
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        ;
      end

      def parse(body)
        JSON.parse(JSON.parse(body)['data'])
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        headers = {
          'Content-Type' => 'application/json',
        }
        response = parse(ssl_post(url, post_data(action, parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['avs_response']),
          cvv_result: CVVResult.new(response['cvv_response']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['state'] == 'success'
      end

      def message_from(response)
        response['message']
      end

      def authorization_from(response)
        ;
      end

      def post_data(action, parameters = {})
        # Since we're using echo server, we're embedding response into request
        parameters['avs_response'] = 'R' # Unknown
        parameters['cvv_response'] = 'M' # CVV Matches
        parameters['state'] = 'success'
        parameters['message'] = 'Successful transfer'

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
