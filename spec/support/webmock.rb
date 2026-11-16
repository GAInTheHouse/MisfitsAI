# frozen_string_literal: true

require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before do
    stub_request(:get, %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: { main: { temp: 72 }, weather: [ { main: "Sunny" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
