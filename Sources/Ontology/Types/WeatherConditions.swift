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
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Encode @context if we're at the root level
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }

        // Encode @type
        try container.encode(
            "https://developer.apple.com/WeatherKit/#/WeatherConditions", forKey: .type)

        // Encode properties
        try container.encode(QuantitativeValue(temperature), forKey: .attribute(.temperature))
        try container.encode(
            QuantitativeValue(apparentTemperature), forKey: .attribute(.apparentTemperature))
        try container.encode(QuantitativeValue.percentage(humidity), forKey: .attribute(.humidity))
        try container.encode(QuantitativeValue(windSpeed), forKey: .attribute(.windSpeed))
        try container.encode(condition, forKey: .attribute(.condition))
        if let precipitationChance = precipitationChance {
            try container.encode(
                QuantitativeValue.percentage(precipitationChance),
                forKey: .attribute(.precipitationChance))
        }
        try container.encode(DateTime(dateTime), forKey: .attribute(.dateTime))

        // Provider attribution (set by the producing bridge/backend)
        try container.encodeIfPresent(provider, forKey: .attribute(.provider))
        try container.encodeIfPresent(attribution, forKey: .attribute(.attribution))
        try container.encodeIfPresent(attributionLink, forKey: .attribute(.attributionLink))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Verify type is correct
        let expectedType = "https://developer.apple.com/WeatherKit/#/WeatherConditions"
        let decodedType = try container.decode(String.self, forKey: .type)
        guard decodedType == expectedType else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription:
                    "Expected type to be '\(expectedType)', but found \(decodedType)"
            )
        }

        // Decode properties
        dateTime = try container.decode(DateTime.self, forKey: .attribute(.dateTime)).value

        let tempValue = try container.decode(
            QuantitativeValue.self, forKey: .attribute(.temperature))
        guard let temp = tempValue.measurement(as: UnitTemperature.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .attribute(.temperature),
                in: container,
                debugDescription: "Could not convert temperature QuantitativeValue to Measurement"
            )
        }
        temperature = temp

        let apparentTempValue = try container.decode(
            QuantitativeValue.self, forKey: .attribute(.apparentTemperature))
        guard let apparentTemp = apparentTempValue.measurement(as: UnitTemperature.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .attribute(.apparentTemperature),
                in: container,
                debugDescription:
                    "Could not convert apparent temperature QuantitativeValue to Measurement"
            )
        }
        apparentTemperature = apparentTemp

        let humidityValue = try container.decode(
            QuantitativeValue.self, forKey: .attribute(.humidity))
        humidity = humidityValue.value / 100.0

        let windSpeedValue = try container.decode(
            QuantitativeValue.self, forKey: .attribute(.windSpeed))
        guard let speed = windSpeedValue.measurement(as: UnitSpeed.self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .attribute(.windSpeed),
                in: container,
                debugDescription: "Could not convert wind speed QuantitativeValue to Measurement"
            )
        }
        windSpeed = speed

        condition = try container.decode(String.self, forKey: .attribute(.condition))

        if let precipChance = try container.decodeIfPresent(
            QuantitativeValue.self,
            forKey: .attribute(.precipitationChance)
        ) {
            precipitationChance = precipChance.value / 100.0
        }

        provider = try container.decodeIfPresent(String.self, forKey: .attribute(.provider))
        attribution = try container.decodeIfPresent(String.self, forKey: .attribute(.attribution))
        attributionLink = try container.decodeIfPresent(
            String.self, forKey: .attribute(.attributionLink))
    }
}
