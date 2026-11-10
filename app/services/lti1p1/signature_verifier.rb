module Lti1p1
  class SignatureVerifier
    def initialize(method:, url:, params:, secret:)
      @method = method
      @url = url
      @params = params
      @secret = secret
    end

    def self.percent_encode(value)
      ERB::Util.url_encode(value)
    end

    def base_string
      encoded_url = self.class.percent_encode(normalized_url)
      encoded_params = all_params
        .map { |k, v| [self.class.percent_encode(k), self.class.percent_encode(v)] }
        .sort
        .map { |k, v| "#{k}=#{v}" }
        .join("&")
      "#{@method.upcase}&#{encoded_url}&#{self.class.percent_encode(encoded_params)}"
    end

    def valid?
      received = @params["oauth_signature"]
      return false if received.blank?
      return false unless @params["oauth_signature_method"] == "HMAC-SHA1"

      ActiveSupport::SecurityUtils.secure_compare(signature, received)
    end

    def signature
      key = "#{self.class.percent_encode(@secret)}&"
      Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", key, base_string))
    end

    private

    # Scheme and host in lowercase, no default port, no query string.
    def normalized_url
      uri = URI.parse(@url)
      port = uri.port == uri.default_port ? "" : ":#{uri.port}"
      "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}#{uri.path}"
    end

    # Body params plus URL query params, without oauth_signature.
    # An identical name and value that appears in both places counts once.
    def all_params
      body_pairs = @params.to_a.map { |k, v| [k.to_s, v.to_s] }
      query_pairs = URI.decode_www_form(URI.parse(@url).query.to_s)
      (body_pairs + query_pairs).uniq.reject { |k, _| k == "oauth_signature" }
    end
  end
end
