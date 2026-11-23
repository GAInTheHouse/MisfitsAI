# frozen_string_literal: true

Before do
  ENV["WEATHER_API_KEY"] = "test-weather-key"
  stub_request(:get, %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather})
    .to_return(
      status: 200,
      body: { main: { temp: 72 }, weather: [ { main: "Sunny" } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

Before("@cold_weather") do
  stub_request(:get, %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather})
    .to_return(
      status: 200,
      body: { main: { temp: 48 }, weather: [ { main: "Clouds" } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

Before("@hot_weather") do
  stub_request(:get, %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather})
    .to_return(
      status: 200,
      body: { main: { temp: 88 }, weather: [ { main: "Clear" } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
