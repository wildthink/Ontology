import Foundation

/// A structured value representing a weather forecast.
public struct WeatherForecast: Hashable, Sendable {
    /// The date and time of the forecast
    public var dateTime: Date

    /// The SF Symbol icon that represents the weather condition
    public var symbolName: String?

    // MARK: Temperature

    /// The temperature in Celsius
    public var temperature: Measurement<UnitTemperature>?

    /// The apparent ("feels like") temperature in Celsius
    public var apparentTemperature: Measurement<UnitTemperature>?

    /// The low temperature for the day
    public var lowTemperature: Measurement<UnitTemperature>?

    /// The high temperature for the day
    public var highTemperature: Measurement<UnitTemperature>?

    /// The time at which the high temperature occurs on this day
    public var highTemperatureTime: Date?

    /// The time at which the low temperature occurs on this day
    public var lowTemperatureTime: Date?

    /// The dew point temperature
    public var dewPoint: Measurement<UnitTemperature>?

    // MARK: Humidity

    /// The humidity.
    /// The value is from 0 (0% humidity) to 1 (100% humidity)
    public var humidity: Double?

    /// The minimum humidity for the day.
    public var minimumHumidity: Double?

    /// The maximum humidity for the day.
    public var maximumHumidity: Double?

    // MARK: Wind

    /// Wind speed measurement
    public var windSpeed: Measurement<UnitSpeed>?

    /// The wind direction
    public var windDirection: Measurement<UnitAngle>?

    // MARK: Precipitation

    /// The condition description
    public var condition: String?

    /// The type of precipitation (rain, snow, etc.)
    public var precipitation: String?

    /// The probability of precipitation.
    /// The value is from 0 (0% probability) to 1 (100% probability)
    public var precipitationChance: Double?

    /// The precipitation intensity
    public var precipitationIntensity: Measurement<UnitSpeed>?

    /// The precipitation amount
    public var precipitationAmount: Measurement<UnitLength>?

    /// The cloud cover.
    /// The value is from 0 (0% cloud cover) to 1 (100% cloud cover)
    public var cloudCover: Double?

    /// The visibility distance
    public var visibility: Measurement<UnitLength>?

    // TODO: Add cloud cover by altitude levels

    // MARK: Sun and Moon

    /// The UV index
    public var uvIndex: Int?

    /// The sunrise time
    public var sunRiseTime: Date?

    /// The sunset time
    public var sunSetTime: Date?

    /// The lunar phase for the day
    public var moonPhase: String?

    /// The moonrise time
    public var moonriseTime: Date?

    /// The moonset time
    public var moonsetTime: Date?

    /// Whether it is currently daylight
    public var isDaylight: Bool?

    // MARK: Pressure

    /// The atmospheric pressure
    public var pressure: Measurement<UnitPressure>?

    /// The pressure trend (rising, falling, steady)
    public var pressureTrend: String?

    // MARK: Attribution

    /// The name of the data provider (e.g. "Apple Weather", "Open-Meteo")
    public var provider: String?

    /// The attribution statement required by the data provider
    public var attribution: String?

    /// A link to the provider's attribution page
    public var attributionLink: String?

    public init(dateTime: Date) {
        self.dateTime = dateTime
    }
}

// Conform to Codable for JSON-LD serialization
extension WeatherForecast: Codable {
    private enum CodingKeys: String, CodingKey {
        case dateTime, symbolName
        // Temperature
        case temperature, apparentTemperature, lowTemperature, highTemperature
        case highTemperatureTime, lowTemperatureTime
        case dewPoint
        // Humidity
        case humidity, minimumHumidity, maximumHumidity
        // Wind
        case windSpeed, windDirection
        // Precipitation
        case condition, precipitation, precipitationChance, precipitationIntensity,
            precipitationAmount, visibility
        case cloudCover
        // Sun and Moon
        case uvIndex, sunRiseTime, sunSetTime, moonPhase, moonriseTime, moonsetTime, isDaylight
        // Pressure
        case pressure, pressureTrend
        // Add attribution keys
        case provider, attribution, attributionLink
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Basic info
        try container.encode(DateTime(dateTime), forKey: .dateTime)
        try container.encodeIfPresent(symbolName, forKey: .symbolName)

        // Temperature
        if let temperature = temperature {
            try container.encode(QuantitativeValue(temperature), forKey: .temperature)
        }
        if let apparentTemperature = apparentTemperature {
            try container.encode(
                QuantitativeValue(apparentTemperature), forKey: .apparentTemperature)
        }
        if let lowTemperature = lowTemperature {
            try container.encode(
                QuantitativeValue(lowTemperature), forKey: .lowTemperature)
        }
        if let highTemperature = highTemperature {
            try container.encode(
                QuantitativeValue(highTemperature), forKey: .highTemperature)
        }
        if let highTemperatureTime = highTemperatureTime {
            try container.encode(
                DateTime(highTemperatureTime), forKey: .highTemperatureTime)
        }
        if let lowTemperatureTime = lowTemperatureTime {
            try container.encode(
                DateTime(lowTemperatureTime), forKey: .lowTemperatureTime)
        }
        if let dewPoint = dewPoint {
            try container.encode(QuantitativeValue(dewPoint), forKey: .dewPoint)
        }

        // Humidity
        if let humidity = humidity {
            try container.encode(
                QuantitativeValue.percentage(humidity), forKey: .humidity)
        }
        if let minimumHumidity = minimumHumidity {
            try container.encode(
                QuantitativeValue.percentage(minimumHumidity), forKey: .minimumHumidity)
        }
        if let maximumHumidity = maximumHumidity {
            try container.encode(
                QuantitativeValue.percentage(maximumHumidity), forKey: .maximumHumidity)
        }

        // Wind
        if let windSpeed = windSpeed {
            try container.encode(QuantitativeValue(windSpeed), forKey: .windSpeed)
        }
        if let windDirection = windDirection {
            try container.encode(
                QuantitativeValue(windDirection), forKey: .windDirection)
        }

        // Precipitation and conditions
        try container.encodeIfPresent(condition, forKey: .condition)
        try container.encodeIfPresent(precipitation, forKey: .precipitation)
        if let precipitationChance = precipitationChance {
            try container.encode(
                QuantitativeValue.percentage(precipitationChance),
                forKey: .precipitationChance)
        }
        if let precipitationIntensity = precipitationIntensity {
            try container.encode(
                QuantitativeValue(precipitationIntensity),
                forKey: .precipitationIntensity)
        }
        if let precipitationAmount = precipitationAmount {
            try container.encode(
                QuantitativeValue(precipitationAmount), forKey: .precipitationAmount)
        }
        if let cloudCover = cloudCover {
            try container.encode(
                QuantitativeValue.percentage(cloudCover), forKey: .cloudCover)
        }
        if let visibility = visibility {
            try container.encode(QuantitativeValue(visibility), forKey: .visibility)
        }

        // Sun and Moon
        try container.encodeIfPresent(uvIndex, forKey: .uvIndex)
        if let sunRiseTime = sunRiseTime {
            try container.encode(DateTime(sunRiseTime), forKey: .sunRiseTime)
        }
        if let sunSetTime = sunSetTime {
            try container.encode(DateTime(sunSetTime), forKey: .sunSetTime)
        }
        try container.encodeIfPresent(moonPhase, forKey: .moonPhase)
        if let moonriseTime = moonriseTime {
            try container.encode(DateTime(moonriseTime), forKey: .moonriseTime)
        }
        if let moonsetTime = moonsetTime {
            try container.encode(DateTime(moonsetTime), forKey: .moonsetTime)
        }
        try container.encodeIfPresent(isDaylight, forKey: .isDaylight)

        // Pressure
        if let pressure = pressure {
            try container.encode(QuantitativeValue(pressure), forKey: .pressure)
        }
        try container.encodeIfPresent(pressureTrend, forKey: .pressureTrend)

        // Provider attribution (set by the producing bridge/backend)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(attribution, forKey: .attribution)
        try container.encodeIfPresent(attributionLink, forKey: .attributionLink)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Basic info
        dateTime = try container.decode(DateTime.self, forKey: .dateTime).value
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)

        // Temperature
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .temperature)
        {
            temperature = value.measurement(as: UnitTemperature.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .apparentTemperature)
        {
            apparentTemperature = value.measurement(as: UnitTemperature.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .lowTemperature)
        {
            lowTemperature = value.measurement(as: UnitTemperature.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .highTemperature)
        {
            highTemperature = value.measurement(as: UnitTemperature.self)
        }
        highTemperatureTime = try container.decodeIfPresent(
            DateTime.self, forKey: .highTemperatureTime)?.value
        lowTemperatureTime = try container.decodeIfPresent(
            DateTime.self, forKey: .lowTemperatureTime)?.value
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .dewPoint)
        {
            dewPoint = value.measurement(as: UnitTemperature.self)
        }

        // Humidity
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .humidity)
        {
            humidity = value.value / 100.0
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .minimumHumidity)
        {
            minimumHumidity = value.value / 100.0
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .maximumHumidity)
        {
            maximumHumidity = value.value / 100.0
        }

        // Wind
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .windSpeed)
        {
            windSpeed = value.measurement(as: UnitSpeed.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .windDirection)
        {
            windDirection = value.measurement(as: UnitAngle.self)
        }

        // Precipitation and conditions
        condition = try container.decodeIfPresent(String.self, forKey: .condition)
        precipitation = try container.decodeIfPresent(
            String.self, forKey: .precipitation)
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .precipitationChance)
        {
            precipitationChance = value.value / 100.0
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .precipitationIntensity)
        {
            precipitationIntensity = value.measurement(as: UnitSpeed.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .precipitationAmount)
        {
            precipitationAmount = value.measurement(as: UnitLength.self)
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .cloudCover)
        {
            cloudCover = value.value / 100.0
        }
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .visibility)
        {
            visibility = value.measurement(as: UnitLength.self)
        }

        // Sun and Moon
        uvIndex = try container.decodeIfPresent(Int.self, forKey: .uvIndex)
        sunRiseTime = try container.decodeIfPresent(
            DateTime.self, forKey: .sunRiseTime)?.value
        sunSetTime = try container.decodeIfPresent(DateTime.self, forKey: .sunSetTime)?
            .value
        moonPhase = try container.decodeIfPresent(String.self, forKey: .moonPhase)
        moonriseTime = try container.decodeIfPresent(
            DateTime.self, forKey: .moonriseTime)?.value
        moonsetTime = try container.decodeIfPresent(
            DateTime.self, forKey: .moonsetTime)?.value
        isDaylight = try container.decodeIfPresent(Bool.self, forKey: .isDaylight)

        // Pressure and Visibility
        if let value = try container.decodeIfPresent(
            QuantitativeValue.self, forKey: .pressure)
        {
            pressure = value.measurement(as: UnitPressure.self)
        }
        pressureTrend = try container.decodeIfPresent(
            String.self, forKey: .pressureTrend)

        // Attribution
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        attribution = try container.decodeIfPresent(String.self, forKey: .attribution)
        attributionLink = try container.decodeIfPresent(
            String.self, forKey: .attributionLink)
    }
}
