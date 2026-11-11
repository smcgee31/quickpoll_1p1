require "rails_helper"

# Stage 3. Write app/services/lti1p1/signature_verifier.rb until this passes.
#
# Interface these specs expect:
#   Lti1p1::SignatureVerifier.new(method:, url:, params:, secret:)
#     #base_string -> String  (RFC 5849 section 3.4.1)
#     #signature   -> String  (Base64 HMAC-SHA1 of base_string, key "#{encode(secret)}&")
#     #valid?      -> true/false
#   Lti1p1::SignatureVerifier.percent_encode(string) -> String  (RFC 3986 unreserved set only)
#
# `params` is every launch param, including oauth_signature. The verifier drops oauth_signature itself.
# The fixtures are real Canvas launches. The expected signatures came from Canvas, not from this code.

RSpec.describe Lti1p1::SignatureVerifier do
  def fixture(name)
    JSON.parse(Rails.root.join("spec/fixtures/lti1p1/#{name}_launch.json").read)
  end

  def verifier_for(launch, **overrides)
    described_class.new(
      **{ method: "POST", url: launch["url"], params: launch["params"], secret: launch["secret"] }.merge(overrides)
    )
  end

  describe ".percent_encode" do
    it "leaves unreserved characters alone" do
      expect(described_class.percent_encode("AZaz09-._~")).to eq("AZaz09-._~")
    end

    it "encodes everything else as uppercase hex" do
      expect(described_class.percent_encode("r b/c+d=e&f@g:h")).to eq("r%20b%2Fc%2Bd%3De%26f%40g%3Ah")
    end

    it "encodes multibyte characters one byte at a time" do
      expect(described_class.percent_encode("é")).to eq("%C3%A9")
    end
  end

  describe "#base_string" do
    subject(:base_string) { verifier_for(fixture("teacher")).base_string }

    it "starts with the method and the encoded URL" do
      expect(base_string).to start_with("POST&https%3A%2F%2Flti-1p1-test-tool.vercel.app%2Flaunch&")
    end

    it "leaves out oauth_signature" do
      expect(base_string).not_to match(/oauth_signature%3D/)
    end

    it "keeps params that have an empty value" do
      expect(base_string).to include("lis_person_contact_email_primary%3D%26")
    end

    it "sorts params by encoded name" do
      names = base_string.split("&", 3).last.then { |s| CGI.unescape(s) }.split("&").map { |pair| pair.split("=", 2).first }
      expect(names).to eq(names.sort)
    end
  end

  describe "#valid?" do
    it "accepts the captured teacher launch" do
      expect(verifier_for(fixture("teacher"))).to be_valid
    end

    it "accepts the captured student launch" do
      expect(verifier_for(fixture("student"))).to be_valid
    end

    it "computes the signature Canvas computed" do
      launch = fixture("teacher")
      expect(verifier_for(launch).signature).to eq(launch["params"]["oauth_signature"])
    end

    it "accepts a param that moved from the POST body to the URL query" do
      launch = fixture("teacher")
      params = launch["params"].except("placement")
      url = "#{launch['url']}?placement=course_navigation"

      expect(verifier_for(launch, url: url, params: params)).to be_valid
    end

    # Canvas with "OAuth Compliant" off leaves ?placement=... on the URL AND copies it into the POST body,
    # then signs it once. A literal RFC merge counts it twice and fails. Real launches look like this.
    it "accepts a param that appears in both the URL query and the body with the same value" do
      launch = fixture("teacher")
      url = "#{launch['url']}?placement=course_navigation"

      expect(verifier_for(launch, url: url)).to be_valid
    end

    it "ignores the default port and the case of scheme and host" do
      launch = fixture("teacher")
      url = "HTTPS://LTI-1p1-Test-Tool.vercel.app:443/launch"

      expect(verifier_for(launch, url: url)).to be_valid
    end

    it "rejects a wrong secret" do
      expect(verifier_for(fixture("teacher"), secret: "not-the-secret")).not_to be_valid
    end

    it "rejects a changed param" do
      launch = fixture("teacher")
      params = launch["params"].merge("user_id" => "someone-else")

      expect(verifier_for(launch, params: params)).not_to be_valid
    end

    it "rejects an added param" do
      launch = fixture("teacher")
      params = launch["params"].merge("roles" => "Instructor,Administrator")

      expect(verifier_for(launch, params: params)).not_to be_valid
    end

    it "rejects a launch URL on a different scheme (the proxy bug)" do
      launch = fixture("teacher")

      expect(verifier_for(launch, url: launch["url"].sub("https", "http"))).not_to be_valid
    end

    it "rejects a launch with no oauth_signature" do
      launch = fixture("teacher")

      expect(verifier_for(launch, params: launch["params"].except("oauth_signature"))).not_to be_valid
    end

    it "rejects a signature method other than HMAC-SHA1" do
      launch = fixture("teacher")
      params = launch["params"].merge("oauth_signature_method" => "PLAINTEXT")

      expect(verifier_for(launch, params: params)).not_to be_valid
    end
  end
end
