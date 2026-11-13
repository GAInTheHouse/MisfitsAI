# frozen_string_literal: true

Before do
  stub_request(:get, %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather})
    .to_return(
      status: 200,
      body: { main: { temp: 72 }, weather: [ { main: "Sunny" } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
