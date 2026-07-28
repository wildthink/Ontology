import Foundation

/// A structured value representing weather conditions.
public struct WeatherConditions: Hashable, Sendable {
    /// The date and time of the observation
    public var dateTime: Date

    /// The temperature in Celsius
    public var temperature: Measurement<UnitTemperature>

    /// The apparent ("feels like") temperature in Celsius
    public var apparentTemperature: Measurement<UnitTemperature>

    /// Wind speed measurement
    public var windSpeed: Measurement<UnitSpeed>

    /// The humidity.
    /// The value is from 0 (0% humidity) to 1 (100% humidity)
    public var humidity: Double

    /// The condition description
    public var condition: String

    /// The probability of precipitation during the hour.
    /// The value is from 0 (0% probability) to 1 (100% probability)
    public var precipitationChance: Double?

    /// The name of the data provider (e.g. "Apple Weather", "Open-Meteo")
    public var provider: String?

    /// The attribution statement required by the data provider
    public var attribution: String?

    /// A link to the provider's attribution page
    public var attributionLink: String?

    public init(
        dateTime: Date,
        temperature: Measurement<UnitTemperature>,
        apparentTemperature: Measurement<UnitTemperature>,
        windSpeed: Measurement<UnitSpeed>,
        humidity: Double,
        condition: String,
        precipitationChance: Double? = nil,
        provider: String? = nil,
        attribution: String? = nil,
        attributionLink: String? = nil
    ) {
        self.dateTime = dateTime
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.windSpeed = windSpeed
        self.humidity = humidity
        self.condition = condition
        self.precipitationChance = precipitationChance
        self.provider = provider
        self.attribution = attribution
        self.attributionLink = attributionLink
    }
}

// Conform to Codable for JSON-LD serialization
extension WeatherConditions: Codable {
    private enum CodingKeys: String, CodingKey {
        case dateTime
        case temperature, apparentTemperature
        case humidity
        case windSpeed
        case condition
        case precipitationChance
        case provider, attribution, attributionLink
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode properties
        try container.encode(QuantitativeValue(temperature), forKey: .temperature)
        try container.encode(
            QuantitativeValue(apparentTemperature), forKey: .apparentTemperature)
        try container.encode(QuantitativeValue.percentage(humidity), forKey: .humidity)
        try container.encode(QuantitativeValue(windSpeed), forKey: .windSpeed)
        try container.encode(condition, forKey: .condition)
        if let precipitationChance = precipitationChance {
            try container.encode(
                QuantitativeValue.percentage(precipitationChance),
                forKey: .precipitationChance)
        }
        try container.encode(DateTime(dateTime), forKey: .dateTime)

        // Provider attribution (set by the producing bridge/backend)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(attribution, forKey: .attribution)
        try container.encodeIfPresent(attributionLink, forKey: .attributionLink)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode properties
        dateTime = try container.decode(DateTime.self, forKey: .dateTime).value

        let tempValue = try container.decode(
            QuantitativeValue.self, forKey: .temperature)
        guard let temp = tempValue.measurement(as: UnitTemperature.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .temperature,
                in: container,
                debugDescription: "Could not convert temperature QuantitativeValue to Measurement"
            )
        }
        temperature = temp

        let apparentTempValue = try container.decode(
            QuantitativeValue.self, forKey: .apparentTemperature)
        guard let apparentTemp = apparentTempValue.measurement(as: UnitTemperature.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .apparentTemperature,
                in: container,
                debugDescription:
                    "Could not convert apparent temperature QuantitativeValue to Measurement"
            )
        }
        apparentTemperature = apparentTemp

        let humidityValue = try container.decode(
            QuantitativeValue.self, forKey: .humidity)
        humidity = humidityValue.value / 100.0

        let windSpeedValue = try container.decode(
            QuantitativeValue.self, forKey: .windSpeed)
        guard let speed = windSpeedValue.measurement(as: UnitSpeed.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .windSpeed,
                in: container,
                debugDescription: "Could not convert wind speed QuantitativeValue to Measurement"
            )
        }
        windSpeed = speed

        condition = try container.decode(String.self, forKey: .condition)

        if let precipChance = try container.decodeIfPresent(
            QuantitativeValue.self,
            forKey: .precipitationChance
        ) {
            precipitationChance = precipChance.value / 100.0
        }

        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        attribution = try container.decodeIfPresent(String.self, forKey: .attribution)
        attributionLink = try container.decodeIfPresent(
            String.self, forKey: .attributionLink)
    }
}
