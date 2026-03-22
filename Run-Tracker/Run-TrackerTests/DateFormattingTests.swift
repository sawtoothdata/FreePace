//
//  DateFormattingTests.swift
//  Run-TrackerTests
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Testing
import Foundation
@testable import Run_Tracker

struct DateFormattingTests {

    // MARK: - Duration formatting

    @Test func durationZero() {
        #expect((0.0).asDuration() == "00:00:00")
    }

    @Test func durationOneMinute() {
        #expect((60.0).asDuration() == "00:01:00")
    }

    @Test func durationOneHour() {
        #expect((3600.0).asDuration() == "01:00:00")
    }

    @Test func durationMixed() {
        // 1h 23m 45s = 5025 seconds
        #expect((5025.0).asDuration() == "01:23:45")
    }

    @Test func durationLargeValue() {
        // 10h 0m 0s = 36000 seconds
        #expect((36000.0).asDuration() == "10:00:00")
    }

    @Test func durationNegativeReturnsZero() {
        #expect((-1.0).asDuration() == "00:00:00")
    }

    @Test func durationInfiniteReturnsZero() {
        #expect(Double.infinity.asDuration() == "00:00:00")
    }

    // MARK: - Compact duration

    @Test func compactDurationUnderOneHour() {
        #expect((2537.0).asCompactDuration() == "42:17")
    }

    @Test func compactDurationOverOneHour() {
        #expect((3737.0).asCompactDuration() == "1:02:17")
    }

    @Test func compactDurationZero() {
        #expect((0.0).asCompactDuration() == "0:00")
    }

    @Test func compactDurationUnderOneMinute() {
        #expect((45.0).asCompactDuration() == "0:45")
    }

    // MARK: - Date display formatting

    @Test func runDateDisplayFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7)
        let date = calendar.date(from: components)!
        let result = date.runDateDisplay()
        #expect(result.contains("Mar"))
        #expect(result.contains("7"))
        #expect(result.contains("2026"))
    }

    @Test func runDateTimeDisplayFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 6, minute: 42)
        let date = calendar.date(from: components)!
        let result = date.runDateTimeDisplay()
        #expect(result.contains("Mar"))
        #expect(result.contains("7"))
        #expect(result.contains("2026"))
        #expect(result.contains("6:42"))
    }

    // MARK: - Time of day

    @Test func timeOfDayMorning() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 7)
        let date = calendar.date(from: components)!
        #expect(date.timeOfDayLabel() == "Morning")
    }

    @Test func timeOfDayAfternoon() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 14)
        let date = calendar.date(from: components)!
        #expect(date.timeOfDayLabel() == "Afternoon")
    }

    @Test func timeOfDayEvening() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 19)
        let date = calendar.date(from: components)!
        #expect(date.timeOfDayLabel() == "Evening")
    }

    @Test func timeOfDayNight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 23)
        let date = calendar.date(from: components)!
        #expect(date.timeOfDayLabel() == "Night")
    }
}
