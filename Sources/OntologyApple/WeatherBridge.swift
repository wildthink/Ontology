#if canImport(WeatherKit)
import WeatherKit
import Ontology

/// Attribution required by Apple for WeatherKit-sourced data.
/// https://developer.apple.com/weatherkit/get-started/#attribution-requirements
private enum AppleWeatherAttribution {
    static let provider = "Apple Weather"
    static let attribution = "Weather data provided by Apple Weather"
    static let attributionLink = "https://weatherkit.apple.com/legal-attribution.html"
}

extension WeatherConditions {
    public init(_ current: CurrentWeather) {
        self.init(
            dateTime: current.date,
            temperature: current.temperature,
            apparentTemperature: current.apparentTemperature,
            windSpeed: current.wind.speed,
            humidity: current.humidity,
            condition: current.condition.description,
            provider: AppleWeatherAttribution.provider,
            attribution: AppleWeatherAttribution.attribution,
            attributionLink: AppleWeatherAttribution.attributionLink
        )
    }

    public init(_ forecast: HourWeather) {
        self.init(
            dateTime: forecast.date,
            temperature: forecast.temperature,
            apparentTemperature: forecast.apparentTemperature,
            windSpeed: forecast.wind.speed,
            humidity: forecast.humidity,
            condition: forecast.condition.description,
            precipitationChance: forecast.precipitationChance,
            provider: AppleWeatherAttribution.provider,
            attribution: AppleWeatherAttribution.attribution,
            attributionLink: AppleWeatherAttribution.attributionLink
        )
    }
}

extension WeatherForecast {
    private mutating func applyAppleWeatherAttribution() {
        self.provider = AppleWeatherAttribution.provider
        self.attribution = AppleWeatherAttribution.attribution
        self.attributionLink = AppleWeatherAttribution.attributionLink
    }

    public init(_ forecast: DayWeather) {
        self.init(dateTime: forecast.date)
        self.windSpeed = forecast.wind.speed
        self.lowTemperature = forecast.lowTemperature
        self.highTemperature = forecast.highTemperature
        self.precipitationChance = forecast.precipitationChance
        self.condition = forecast.condition.description
        self.uvIndex = forecast.uvIndex.value
        self.precipitationAmount = forecast.precipitationAmount
        self.applyAppleWeatherAttribution()
    }

    public init(_ forecast: HourWeather) {
        self.init(dateTime: forecast.date)
        self.temperature = forecast.temperature
        self.apparentTemperature = forecast.apparentTemperature
        self.humidity = forecast.humidity
        self.windSpeed = forecast.wind.speed
        self.condition = forecast.condition.description
        self.precipitationChance = forecast.precipitationChance
        self.precipitationAmount = forecast.precipitationAmount
        self.uvIndex = forecast.uvIndex.value
        self.applyAppleWeatherAttribution()
    }

    public init(_ forecast: MinuteWeather) {
        self.init(dateTime: forecast.date)
        self.precipitation = forecast.precipitation.description
        self.precipitationChance = forecast.precipitationChance
        self.precipitationIntensity = forecast.precipitationIntensity
        self.applyAppleWeatherAttribution()
    }
}
#endif
