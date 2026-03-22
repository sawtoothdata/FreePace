//
//  AudioCueServiceTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class AudioCueServiceTests: XCTestCase {

    // MARK: - Spoken Label Tests

    func testSpokenLabelFullImperial() {
        XCTAssertEqual(SplitDistance.full.spokenLabel(for: .imperial), "Mile")
    }

    func testSpokenLabelFullMetric() {
        XCTAssertEqual(SplitDistance.full.spokenLabel(for: .metric), "Kilometer")
    }

    func testSpokenLabelHalfImperial() {
        XCTAssertEqual(SplitDistance.half.spokenLabel(for: .imperial), "Half mile")
    }

    func testSpokenLabelHalfMetric() {
        XCTAssertEqual(SplitDistance.half.spokenLabel(for: .metric), "Half K")
    }

    func testSpokenLabelQuarterImperial() {
        XCTAssertEqual(SplitDistance.quarter.spokenLabel(for: .imperial), "Quarter mile")
    }

    func testSpokenLabelQuarterMetric() {
        XCTAssertEqual(SplitDistance.quarter.spokenLabel(for: .metric), "Quarter K")
    }

    // MARK: - Split Label Tests (visual)

    func testSplitLabelAllCombinations() {
        XCTAssertEqual(SplitDistance.quarter.splitLabel(for: .imperial), "¼ Mi")
        XCTAssertEqual(SplitDistance.half.splitLabel(for: .imperial), "½ Mi")
        XCTAssertEqual(SplitDistance.full.splitLabel(for: .imperial), "Mile")
        XCTAssertEqual(SplitDistance.quarter.splitLabel(for: .metric), "¼ Km")
        XCTAssertEqual(SplitDistance.half.splitLabel(for: .metric), "½ Km")
        XCTAssertEqual(SplitDistance.full.splitLabel(for: .metric), "Km")
    }

    // MARK: - Helper

    private func makeCoachData(
        lastRunCumulative: [TimeInterval],
        currentCumulativeTime: TimeInterval,
        currentSplitDuration: TimeInterval = 480
    ) -> AudioCueService.CoachData {
        // Derive per-split times from cumulative
        var perSplit: [TimeInterval] = []
        for i in 0..<lastRunCumulative.count {
            if i == 0 {
                perSplit.append(lastRunCumulative[i])
            } else {
                perSplit.append(lastRunCumulative[i] - lastRunCumulative[i - 1])
            }
        }
        return AudioCueService.CoachData(
            lastRunCumulativeSplitTimes: lastRunCumulative,
            lastRunPerSplitTimes: perSplit,
            currentCumulativeTime: currentCumulativeTime,
            currentSplitDuration: currentSplitDuration,
            currentSplitPaceSecondsPerMeter: 0.3,
            currentAvgPaceSecondsPerMeter: 0.3
        )
    }

    // MARK: - Coach Comparison Text Tests

    func testCoachComparisonAhead() {
        let data = makeCoachData(
            lastRunCumulative: [480, 960],
            currentCumulativeTime: 470,
            currentSplitDuration: 470
        )
        let text = AudioCueService.coachComparisonText(splitIndex: 1, coachData: data)
        XCTAssertTrue(text.contains("10 seconds faster than last run"))
    }

    func testCoachComparisonBehind() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 495,
            currentSplitDuration: 495
        )
        let text = AudioCueService.coachComparisonText(splitIndex: 1, coachData: data)
        XCTAssertTrue(text.contains("15 seconds slower than last run"))
    }

    func testCoachComparisonExact() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 480,
            currentSplitDuration: 480
        )
        let text = AudioCueService.coachComparisonText(splitIndex: 1, coachData: data)
        XCTAssertTrue(text.contains("0 seconds faster than last run"))
    }

    func testCoachComparisonBeyondData() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 1000
        )
        // Split index 3 means splitIdx0 = 2, beyond the array (count=1)
        let text = AudioCueService.coachComparisonText(splitIndex: 3, coachData: data)
        XCTAssertEqual(text, "")
    }

    func testCoachComparisonSingularSecond() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 481,
            currentSplitDuration: 481
        )
        let text = AudioCueService.coachComparisonText(splitIndex: 1, coachData: data)
        XCTAssertTrue(text.contains("1 second slower than last run"))
    }

    func testCoachComparisonTotalTimeOnly() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 470,
            currentSplitDuration: 470
        )
        let text = AudioCueService.coachComparisonText(
            splitIndex: 1,
            coachData: data,
            enabledFields: [.totalTimeVsLastRun]
        )
        XCTAssertTrue(text.contains("Total time: 10 seconds faster than last run."))
        XCTAssertFalse(text.contains("Split time"))
        XCTAssertFalse(text.contains("Split pace"))
        XCTAssertFalse(text.contains("Average pace"))
    }

    func testCoachComparisonSplitTimeOnly() {
        let data = makeCoachData(
            lastRunCumulative: [480],
            currentCumulativeTime: 470,
            currentSplitDuration: 470
        )
        let text = AudioCueService.coachComparisonText(
            splitIndex: 1,
            coachData: data,
            enabledFields: [.splitTimeVsLastRun]
        )
        XCTAssertTrue(text.contains("Split time: 10 seconds faster than last run."))
        XCTAssertFalse(text.contains("Total time"))
    }

    // MARK: - Cool-Down Prefix Tests

    func testCoolDownPrefixWhenActive() {
        XCTAssertEqual(AudioCueService.coolDownPrefix(isActive: true), "Walking — ")
    }

    func testCoolDownPrefixWhenInactive() {
        XCTAssertEqual(AudioCueService.coolDownPrefix(isActive: false), "")
    }

    func testCoolDownPrefixInSplitCueString() {
        let prefix = AudioCueService.coolDownPrefix(isActive: true)
        let text = "\(prefix)Mile 1. 8 minutes 30 seconds."
        XCTAssertTrue(text.hasPrefix("Walking — "))
        XCTAssertTrue(text.contains("Mile 1"))
    }

    func testNoCoolDownPrefixInSplitCueString() {
        let prefix = AudioCueService.coolDownPrefix(isActive: false)
        let text = "\(prefix)Mile 1. 8 minutes 30 seconds."
        XCTAssertTrue(text.hasPrefix("Mile 1"))
    }

    func testCoolDownPrefixInTimeCueString() {
        let prefix = AudioCueService.coolDownPrefix(isActive: true)
        let text = "\(prefix)10 minutes. 1.5 miles."
        XCTAssertTrue(text.hasPrefix("Walking — "))
        XCTAssertTrue(text.contains("10 minutes"))
    }

    func testIsCoolDownActivePropertyOnService() {
        let service = AudioCueService()
        XCTAssertFalse(service.isCoolDownActive)
        service.isCoolDownActive = true
        XCTAssertTrue(service.isCoolDownActive)
    }

    // MARK: - Checkpoint Announcement Tests

    func testCheckpointAnnouncementBasic() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 1",
            elapsedSeconds: 125,
            distanceMeters: 500,
            unitSystem: .imperial,
            previousDelta: nil,
            averageDelta: nil
        )
        XCTAssertTrue(text.contains("Checkpoint 1. 2 minutes 5 seconds."))
        XCTAssertTrue(text.contains("0.31 mi."))
    }

    func testCheckpointAnnouncementWithPreviousDeltaAhead() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 2",
            elapsedSeconds: 300,
            distanceMeters: 1000,
            unitSystem: .imperial,
            previousDelta: -10,
            averageDelta: nil
        )
        XCTAssertTrue(text.contains("Checkpoint 2. 5 minutes."))
        XCTAssertTrue(text.contains("10 seconds ahead of your last run."))
        // Should NOT contain distance since previousDelta is present
        XCTAssertFalse(text.contains("mi."))
    }

    func testCheckpointAnnouncementWithPreviousDeltaBehind() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 3",
            elapsedSeconds: 600,
            distanceMeters: 2000,
            unitSystem: .imperial,
            previousDelta: 15,
            averageDelta: nil
        )
        XCTAssertTrue(text.contains("15 seconds behind your last run."))
    }

    func testCheckpointAnnouncementWithAverageDelta() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 1",
            elapsedSeconds: 120,
            distanceMeters: 800,
            unitSystem: .imperial,
            previousDelta: nil,
            averageDelta: -8
        )
        XCTAssertTrue(text.contains("8 seconds ahead of your average."))
        // Should NOT contain distance since averageDelta is present
        XCTAssertFalse(text.contains("mi."))
    }

    func testCheckpointAnnouncementWithBothDeltas() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 1",
            elapsedSeconds: 180,
            distanceMeters: 1000,
            unitSystem: .imperial,
            previousDelta: -5,
            averageDelta: 3
        )
        XCTAssertTrue(text.contains("Checkpoint 1. 3 minutes."))
        XCTAssertTrue(text.contains("5 seconds ahead of your last run."))
        XCTAssertTrue(text.contains("3 seconds behind your average."))
    }

    func testCheckpointAnnouncementSingularSecond() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "CP",
            elapsedSeconds: 61,
            distanceMeters: 300,
            unitSystem: .imperial,
            previousDelta: 1,
            averageDelta: -1
        )
        XCTAssertTrue(text.contains("1 minute 1 second."))
        XCTAssertTrue(text.contains("1 second behind your last run."))
        XCTAssertTrue(text.contains("1 second ahead of your average."))
    }

    func testCheckpointAnnouncementExactZeroDelta() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 1",
            elapsedSeconds: 120,
            distanceMeters: 600,
            unitSystem: .imperial,
            previousDelta: 0,
            averageDelta: 0
        )
        XCTAssertTrue(text.contains("0 seconds ahead of your last run."))
        XCTAssertTrue(text.contains("0 seconds ahead of your average."))
    }

    func testCheckpointAnnouncementNoHistoryIncludesDistance() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "New Pin",
            elapsedSeconds: 300,
            distanceMeters: 1609.34,
            unitSystem: .imperial,
            previousDelta: nil,
            averageDelta: nil
        )
        XCTAssertTrue(text.contains("New Pin. 5 minutes."))
        XCTAssertTrue(text.contains("1.00 mi."))
        // Should NOT contain delta text
        XCTAssertFalse(text.contains("ahead"))
        XCTAssertFalse(text.contains("behind"))
    }

    func testCheckpointAnnouncementNoHistoryMetric() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "Checkpoint 1",
            elapsedSeconds: 240,
            distanceMeters: 1000,
            unitSystem: .metric,
            previousDelta: nil,
            averageDelta: nil
        )
        XCTAssertTrue(text.contains("Checkpoint 1. 4 minutes."))
        XCTAssertTrue(text.contains("1.00 km."))
    }

    // MARK: - Lap Announcement Tests

    func testCheckpointAnnouncementWithLapNumber() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "CP1",
            elapsedSeconds: 120,
            distanceMeters: 500,
            unitSystem: .imperial,
            previousDelta: nil,
            averageDelta: nil,
            lapNumber: 2
        )
        XCTAssertTrue(text.hasPrefix("Lap 2. "), "Should start with lap number")
        XCTAssertTrue(text.contains("CP1. 2 minutes."))
    }

    func testCheckpointAnnouncementWithoutLapNumber() {
        let text = AudioCueService.checkpointAnnouncementText(
            label: "CP1",
            elapsedSeconds: 120,
            distanceMeters: 500,
            unitSystem: .imperial,
            previousDelta: nil,
            averageDelta: nil,
            lapNumber: nil
        )
        XCTAssertTrue(text.hasPrefix("CP1."), "Should start with label, no lap prefix")
    }

    func testLapCompletionAnnouncement() {
        let text = AudioCueService.lapCompletionText(
            lapNumber: 2,
            lapTime: 94,
            totalElapsed: 188
        )
        XCTAssertTrue(text.contains("Lap 2 complete."))
        XCTAssertTrue(text.contains("1 minute 34 seconds."))
        XCTAssertTrue(text.contains("Total time: 3 minutes 8 seconds."))
    }

    func testLapCompletionAnnouncementExactMinute() {
        let text = AudioCueService.lapCompletionText(
            lapNumber: 1,
            lapTime: 120,
            totalElapsed: 120
        )
        XCTAssertTrue(text.contains("Lap 1 complete."))
        XCTAssertTrue(text.contains("2 minutes."))
        XCTAssertTrue(text.contains("Total time: 2 minutes."))
    }
}
