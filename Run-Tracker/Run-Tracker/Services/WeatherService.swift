//
//  WeatherService.swift
//  Run-Tracker
//

import Foundation
import WeatherKit
import CoreLocation

/// Snapshot of weather conditions at a point in time
struct WeatherSnapshot {
    let temperatureCelsius: Double
    let feelsLikeCelsius: Double
    let humidityPercent: Double      // 0.0–1.0
    let windSpeedMPS: Double         // meters per second
    let conditionName: String        // "clear", "cloudy", "rain", etc.
    let conditionSymbol: String      // SF Symbol name
}

/// Fetches current weather using Apple WeatherKit
final class RunWeatherService {
    static let shared = RunWeatherService()

    private let weatherService = WeatherService.shared

    private init() {}

    /// Fetch current weather for a location. Returns nil on failure.
    func fetchCurrentWeather(for location: CLLocation) async -> WeatherSnapshot? {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            return WeatherSnapshot(
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                feelsLikeCelsius: current.apparentTemperature.converted(to: .celsius).value,
                humidityPercent: current.humidity,
                windSpeedMPS: current.wind.speed.converted(to: .metersPerSecond).value,
                conditionName: Self.conditionName(for: current.condition),
                conditionSymbol: Self.conditionSymbol(for: current.condition)
            )
        } catch {
            print("WeatherService: Failed to fetch weather — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Condition Mapping

    static func conditionName(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:                    return "Clear"
        case .mostlyClear:              return "Mostly Clear"
        case .partlyCloudy:             return "Partly Cloudy"
        case .mostlyCloudy:             return "Mostly Cloudy"
        case .cloudy:                   return "Cloudy"
        case .foggy:                    return "Foggy"
        case .haze:                     return "Haze"
        case .smoky:                    return "Smoky"
        case .breezy:                   return "Breezy"
        case .windy:                    return "Windy"
        case .drizzle:                  return "Drizzle"
        case .rain:                     return "Rain"
        case .heavyRain:                return "Heavy Rain"
        case .freezingDrizzle:          return "Freezing Drizzle"
        case .freezingRain:             return "Freezing Rain"
        case .sleet:                    return "Sleet"
        case .snow:                     return "Snow"
        case .heavySnow:                return "Heavy Snow"
        case .flurries:                 return "Flurries"
        case .blizzard:                 return "Blizzard"
        case .blowingSnow:             return "Blowing Snow"
        case .frigid:                   return "Frigid"
        case .hot:                      return "Hot"
        case .hail:                     return "Hail"
        case .thunderstorms:            return "Thunderstorms"
        case .isolatedThunderstorms:    return "Isolated Thunderstorms"
        case .scatteredThunderstorms:   return "Scattered Thunderstorms"
        case .strongStorms:             return "Strong Storms"
        case .tropicalStorm:            return "Tropical Storm"
        case .hurricane:                return "Hurricane"
        case .sunFlurries:              return "Sun Flurries"
        case .sunShowers:               return "Sun Showers"
        case .blowingDust:              return "Blowing Dust"
        case .wintryMix:                return "Wintry Mix"
        @unknown default:               return "Unknown"
        }
    }

    static func conditionSymbol(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:                    return "sun.max.fill"
        case .mostlyClear:              return "sun.min.fill"
        case .partlyCloudy:             return "cloud.sun.fill"
        case .mostlyCloudy:             return "cloud.fill"
        case .cloudy:                   return "cloud.fill"
        case .foggy:                    return "cloud.fog.fill"
        case .haze:                     return "sun.haze.fill"
        case .smoky:                    return "smoke.fill"
        case .breezy, .windy:           return "wind"
        case .drizzle:                  return "cloud.drizzle.fill"
        case .rain:                     return "cloud.rain.fill"
        case .heavyRain:                return "cloud.heavyrain.fill"
        case .freezingDrizzle,
             .freezingRain:             return "cloud.sleet.fill"
        case .sleet, .wintryMix:        return "cloud.sleet.fill"
        case .snow:                     return "cloud.snow.fill"
        case .heavySnow, .blizzard,
             .blowingSnow:              return "cloud.snow.fill"
        case .flurries, .sunFlurries:   return "cloud.snow.fill"
        case .frigid:                   return "thermometer.snowflake"
        case .hot:                      return "thermometer.sun.fill"
        case .hail:                     return "cloud.hail.fill"
        case .thunderstorms,
             .isolatedThunderstorms,
             .scatteredThunderstorms,
             .strongStorms:             return "cloud.bolt.rain.fill"
        case .tropicalStorm,
             .hurricane:                return "tropicalstorm"
        case .sunShowers:               return "cloud.sun.rain.fill"
        case .blowingDust:              return "sun.dust.fill"
        @unknown default:               return "cloud.fill"
        }
    }
}
