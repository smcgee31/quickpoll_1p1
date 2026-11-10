require "rails_helper"

RSpec.describe "GET /lti/config", type: :request do
  it "returns an XML cartridge that points Canvas at the launch URL" do
    get "/lti/config"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/xml")
    doc = Nokogiri::XML(response.body)
    launch_url = doc.at_xpath("//blti:launch_url", "blti" => "http://www.imsglobal.org/xsd/imsbasiclti_v1p0").text
    expect(launch_url).to end_with("/lti/launch")
  end

  it "allows the launch response to render in a Canvas iframe" do
    post "/lti/launch", params: { user_id: "abc" }

    expect(response.headers["X-Frame-Options"]).to be_nil
  end
end
