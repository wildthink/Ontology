#if canImport(WeatherKit)
import WeatherKit
import Ontology

extension WeatherConditions {
    public init(_ current: CurrentWeather) {
        self.init(
            dateTime: current.date,
            temperature: current.temperature,
            apparentTemperature: current.apparentTemperature,
            windSpeed: current.wind.speed,
            humidity: current.humidity,
            condition: current.condition.description
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
            precipitationChance: forecast.precipitationChance
        )
    }
}

extension WeatherForecast {
    public init(_ forecast: DayWeather) {
        self.init(dateTime: forecast.date)
        self.windSpeed = forecast.wind.speed
        self.lowTemperature = forecast.lowTemperature
        self.highTemperature = forecast.highTemperature
        self.precipitationChance = forecast.precipitationChance
        self.condition = forecast.condition.description
        self.uvIndex = forecast.uvIndex.value
        self.precipitationAmount = forecast.precipitationAmount
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
    }

    public init(_ forecast: MinuteWeather) {
        self.init(dateTime: forecast.date)
        self.precipitation = forecast.precipitation.description
        self.precipitationChance = forecast.precipitationChance
        self.precipitationIntensity = forecast.precipitationIntensity
    }
}
#endif
