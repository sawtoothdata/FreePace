//
//  AudioCueService.swift
//  Run-Tracker
//
//  Task 17.1 — Background audio cue fix notes:
//  Root cause analysis:
//  1. AVAudioSession category (.playback) — was already correct.
//  2. Session deactivation between cues — was already guarded by isRunActive,
//     but session was not activated until the first speak() call. Fixed: now
//     activated eagerly in startListening() so the session stays active for the
//     entire run, preventing iOS from suspending the app between cues.
//  3. AVSpeechSynthesizer lifetime — already retained as a stored property. OK.
//  4. UIBackgroundModes — Info.plist already had both "audio" and "location". OK.
//  5. Split publisher re-subscribe on resume — splitTracker is not recreated on
//     resume, so the publisher stays valid. OK.
//  6. beginBackgroundTask — was missing. Added around each utterance so iOS
//     grants extra time to finish speech before suspending.

import AVFoundation
import Combine
import UIKit

@Observable
final class AudioCueService: NSObject {
    // MARK: - Configuration (driven by @AppStorage in SettingsView)

    var isEnabled: Bool = false
    var cueAtSplits: Bool = true
    var cueAtTimeIntervals: Bool = false
    var timeIntervalMinutes: Int = 5 // 1, 5, or 10

    // MARK: - Configurable Fields

    var enabledFields: Set<AudioCueField> = Set(AudioCueField.allCases)

    // MARK: - Coach Mode

    var isCoolDownActive: Bool = false
    var isCoachModeEnabled: Bool = false

    struct CoachData {
        let lastRunCumulativeSplitTimes: [TimeInterval]
        let lastRunPerSplitTimes: [TimeInterval]
        let currentCumulativeTime: TimeInterval
        let currentSplitDuration: TimeInterval
        let currentSplitPaceSecondsPerMeter: Double
        let currentAvgPaceSecondsPerMeter: Double
    }

    var coachData: CoachData?

    // MARK: - Background State

    /// When true, the audio session stays active between utterances to prevent iOS
    /// from suspending the app during background tracking.
    var isRunActive: Bool = false

    // MARK: - Private State

    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    private var lastTimeIntervalCue: Int = 0 // last elapsed minute boundary we announced
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Snapshot of current run stats for time-interval cues
    private var currentElapsedSeconds: Double = 0
    private var currentDistanceMeters: Double = 0
    private var currentAvgPaceSecondsPerMeter: Double = 0
    private var currentLastSplitPaceSecondsPerMeter: Double = 0
    private var currentUnitSystem: UnitSystem = .default
    private var currentSplitDistance: SplitDistance = .full

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Lifecycle

    func startListening(
        splitPublisher: AnyPublisher<SplitSnapshot, Never>,
        unitSystem: UnitSystem,
        splitDistance: SplitDistance = .full
    ) {
        stopListening()
        isRunActive = true
        currentUnitSystem = unitSystem
        currentSplitDistance = splitDistance
        lastTimeIntervalCue = 0

        // Activate audio session eagerly so iOS keeps the app alive in background
        activateAudioSession()

        // Subscribe to split events
        splitPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] split in
                self?.handleSplit(split)
            }
            .store(in: &cancellables)

        // .common run loop mode is required for timer to fire during background execution
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkTimeIntervalCue()
            }
    }

    func updateRunStats(elapsedSeconds: Double, distanceMeters: Double, avgPaceSecondsPerMeter: Double, lastSplitPaceSecondsPerMeter: Double = 0) {
        currentElapsedSeconds = elapsedSeconds
        currentDistanceMeters = distanceMeters
        currentAvgPaceSecondsPerMeter = avgPaceSecondsPerMeter
        currentLastSplitPaceSecondsPerMeter = lastSplitPaceSecondsPerMeter
    }

    func stopListening() {
        isRunActive = false
        cancellables.removeAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        synthesizer.stopSpeaking(at: .immediate)
        endSpeechBackgroundTask()
        deactivateAudioSession()
    }

    // MARK: - Split Handler

    private func handleSplit(_ split: SplitSnapshot) {
        guard isEnabled, cueAtSplits, !split.isPartial else { return }

        let unit = currentUnitSystem
        let fields = enabledFields
        let walkingPrefix = isCoolDownActive ? "Walking — " : ""
        let splitLabel = currentSplitDistance.spokenLabel(for: unit)
        let splitPace = split.distanceMeters > 0 ? split.durationSeconds / split.distanceMeters : 0

        var parts: [String] = ["\(walkingPrefix)\(splitLabel) \(split.splitIndex)."]

        if fields.contains(.totalDistance) {
            let distStr = formatDistanceSpeech(currentDistanceMeters, unit: unit)
            parts.append(distStr + ".")
        }

        if fields.contains(.totalTime) {
            let totalTimeStr = formatDurationSpeech(currentElapsedSeconds)
            parts.append("Total time: \(totalTimeStr).")
        }

        if fields.contains(.splitTime) {
            let splitTimeStr = formatDurationSpeech(split.durationSeconds)
            parts.append(splitTimeStr + ".")
        }

        if fields.contains(.splitPace) {
            let splitPaceStr = formatPaceSpeech(splitPace, unit: unit)
            parts.append("Split pace: \(splitPaceStr).")
        }

        if fields.contains(.averagePace) {
            let avgPaceStr = formatPaceSpeech(currentAvgPaceSecondsPerMeter, unit: unit)
            parts.append("Average pace: \(avgPaceStr).")
        }

        // Coach mode comparisons
        if isCoachModeEnabled, let coachData = coachData {
            let coachParts = AudioCueService.coachComparisonText(
                splitIndex: split.splitIndex,
                coachData: coachData,
                enabledFields: fields,
                unitSystem: unit
            )
            if !coachParts.isEmpty {
                parts.append(coachParts)
            }
        }

        speak(parts.joined(separator: " "))
    }

    // MARK: - Time Interval Check

    private func checkTimeIntervalCue() {
        guard isEnabled, cueAtTimeIntervals, timeIntervalMinutes > 0 else { return }

        let elapsedMinutes = Int(currentElapsedSeconds) / 60
        let intervalBoundary = (elapsedMinutes / timeIntervalMinutes) * timeIntervalMinutes

        guard intervalBoundary > 0, intervalBoundary > lastTimeIntervalCue else { return }

        lastTimeIntervalCue = intervalBoundary

        let unit = currentUnitSystem
        let fields = enabledFields
        let walkingPrefix = isCoolDownActive ? "Walking — " : ""

        var parts: [String] = []

        if fields.contains(.totalTime) {
            let timeStr = formatMinutesSpeech(intervalBoundary)
            parts.append("\(walkingPrefix)\(timeStr).")
        } else {
            // Always include time marker as the lead even if totalTime is off
            parts.append("\(walkingPrefix)\(formatMinutesSpeech(intervalBoundary)).")
        }

        if fields.contains(.totalDistance) {
            let distanceStr = formatDistanceSpeech(currentDistanceMeters, unit: unit)
            parts.append(distanceStr + ".")
        }

        if fields.contains(.averagePace) {
            let paceStr = formatPaceSpeech(currentAvgPaceSecondsPerMeter, unit: unit)
            parts.append("Average pace: \(paceStr).")
        }

        if fields.contains(.splitPace), currentLastSplitPaceSecondsPerMeter > 0 {
            let lastSplitStr = formatPaceSpeech(currentLastSplitPaceSecondsPerMeter, unit: unit)
            parts.append("Last split: \(lastSplitStr).")
        }

        speak(parts.joined(separator: " "))
    }

    // MARK: - Checkpoint Announcement

    func announceCheckpoint(label: String, elapsedSeconds: Double, distanceMeters: Double, unitSystem: UnitSystem, previousDelta: Double?, averageDelta: Double?, lapNumber: Int? = nil) {
        guard isEnabled else { return }
        let text = AudioCueService.checkpointAnnouncementText(
            label: label,
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            unitSystem: unitSystem,
            previousDelta: previousDelta,
            averageDelta: averageDelta,
            lapNumber: lapNumber
        )
        speak(text)
    }

    static func checkpointAnnouncementText(label: String, elapsedSeconds: Double, distanceMeters: Double, unitSystem: UnitSystem, previousDelta: Double?, averageDelta: Double?, lapNumber: Int? = nil) -> String {
        let totalSeconds = Int(elapsedSeconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let timeStr: String
        if m > 0 && s > 0 {
            timeStr = "\(m) \(m == 1 ? "minute" : "minutes") \(s) \(s == 1 ? "second" : "seconds")"
        } else if m > 0 {
            timeStr = "\(m) \(m == 1 ? "minute" : "minutes")"
        } else {
            timeStr = "\(s) \(s == 1 ? "second" : "seconds")"
        }

        var text = ""
        if let lap = lapNumber {
            text += "Lap \(lap). "
        }
        text += "\(label). \(timeStr)."

        // If no comparison data, announce distance instead
        if previousDelta == nil && averageDelta == nil {
            let distValue = distanceMeters / unitSystem.metersPerDistanceUnit
            let distStr = String(format: "%.2f %@", distValue, unitSystem.distanceUnit)
            text += " \(distStr)."
        }

        if let delta = previousDelta {
            let absDelta = Int(abs(delta))
            let aheadBehind = delta <= 0 ? "ahead of" : "behind"
            text += " \(absDelta) \(absDelta == 1 ? "second" : "seconds") \(aheadBehind) your last run."
        }

        if let delta = averageDelta {
            let absDelta = Int(abs(delta))
            let aheadBehind = delta <= 0 ? "ahead of" : "behind"
            text += " \(absDelta) \(absDelta == 1 ? "second" : "seconds") \(aheadBehind) your average."
        }

        return text
    }

    // MARK: - Lap Completion Announcement

    func announceLapCompletion(lapNumber: Int, lapTime: Double, totalElapsed: Double, unitSystem: UnitSystem) {
        guard isEnabled else { return }
        let text = AudioCueService.lapCompletionText(
            lapNumber: lapNumber,
            lapTime: lapTime,
            totalElapsed: totalElapsed
        )
        speak(text)
    }

    static func lapCompletionText(lapNumber: Int, lapTime: Double, totalElapsed: Double) -> String {
        let lapSeconds = Int(lapTime)
        let lm = lapSeconds / 60
        let ls = lapSeconds % 60
        let lapTimeStr: String
        if lm > 0 && ls > 0 {
            lapTimeStr = "\(lm) \(lm == 1 ? "minute" : "minutes") \(ls) \(ls == 1 ? "second" : "seconds")"
        } else if lm > 0 {
            lapTimeStr = "\(lm) \(lm == 1 ? "minute" : "minutes")"
        } else {
            lapTimeStr = "\(ls) \(ls == 1 ? "second" : "seconds")"
        }

        let totalSeconds = Int(totalElapsed)
        let tm = totalSeconds / 60
        let ts = totalSeconds % 60
        let totalStr: String
        if tm > 0 && ts > 0 {
            totalStr = "\(tm) \(tm == 1 ? "minute" : "minutes") \(ts) \(ts == 1 ? "second" : "seconds")"
        } else if tm > 0 {
            totalStr = "\(tm) \(tm == 1 ? "minute" : "minutes")"
        } else {
            totalStr = "\(ts) \(ts == 1 ? "second" : "seconds")"
        }

        return "Lap \(lapNumber) complete. \(lapTimeStr). Total time: \(totalStr)."
    }

    /// Speak a one-shot cue (e.g. mode transition announcements)
    func speakOneShot(_ text: String) {
        guard isEnabled else { return }
        speak(text)
    }

    /// Announce countdown completion — always plays regardless of isEnabled,
    /// since it is tied to the countdown UI, not configurable audio cue settings.
    func speakCountdownComplete() {
        speak("Let's Go!")
    }

    /// Announce run completion — always plays regardless of isEnabled.
    func speakRunComplete() {
        speak("Run complete. Great job!")
    }

    // MARK: - Speech

    private var _cachedVoice: AVSpeechSynthesisVoice?
    private var _hasResolvedVoice = false

    private var preferredVoice: AVSpeechSynthesisVoice? {
        if !_hasResolvedVoice {
            _hasResolvedVoice = true
            let lang = AVSpeechSynthesisVoice.currentLanguageCode()
            let allVoices = AVSpeechSynthesisVoice.speechVoices()

            // Try exact locale match first, picking highest quality
            let exactVoices = allVoices
                .filter { $0.language == lang }
                .sorted { $0.quality.rawValue > $1.quality.rawValue }

            if let best = exactVoices.first, best.quality != .default {
                _cachedVoice = best
            } else {
                // Broaden to same language family (e.g. any "en-*" premium/enhanced voice)
                let langPrefix = String(lang.prefix(2))
                let familyVoices = allVoices
                    .filter { $0.language.hasPrefix(langPrefix) }
                    .sorted { $0.quality.rawValue > $1.quality.rawValue }

                if let best = familyVoices.first, best.quality != .default {
                    _cachedVoice = best
                } else {
                    _cachedVoice = exactVoices.first ?? AVSpeechSynthesisVoice(language: lang)
                }
            }
        }
        return _cachedVoice
    }

    private func speak(_ text: String) {
        activateAudioSession()
        beginSpeechBackgroundTask()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice
        utterance.preUtteranceDelay = 0.15
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Background Task

    private func beginSpeechBackgroundTask() {
        endSpeechBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioCueSpeech") { [weak self] in
            self?.endSpeechBackgroundTask()
        }
    }

    private func endSpeechBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Audio Session

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .duckOthers)
            try session.setActive(true)
        } catch {
            // Silently fail — audio cues are a nice-to-have
        }
    }

    private func deactivateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Silently fail
        }
    }

    // MARK: - Formatting Helpers

    private func formatDurationSpeech(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if m > 0 && s > 0 {
            return "\(m) \(m == 1 ? "minute" : "minutes") \(s) \(s == 1 ? "second" : "seconds")"
        } else if m > 0 {
            return "\(m) \(m == 1 ? "minute" : "minutes")"
        } else {
            return "\(s) \(s == 1 ? "second" : "seconds")"
        }
    }

    private func formatMinutesSpeech(_ minutes: Int) -> String {
        return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
    }

    private func formatDistanceSpeech(_ meters: Double, unit: UnitSystem) -> String {
        let value = meters / unit.metersPerDistanceUnit
        let unitLabel = unit == .imperial ? (value == 1.0 ? "mile" : "miles") : "kilometers"
        return String(format: "%.1f %@", value, unitLabel)
    }

    private func formatPaceSpeech(_ secondsPerMeter: Double, unit: UnitSystem) -> String {
        guard secondsPerMeter > 0, secondsPerMeter.isFinite else { return "unknown" }
        let secondsPerUnit = secondsPerMeter * unit.metersPerDistanceUnit
        guard secondsPerUnit < 3600 else { return "unknown" }
        let totalSeconds = Int(secondsPerUnit)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let unitLabel = unit == .imperial ? "per mile" : "per kilometer"
        return "\(m) \(m == 1 ? "minute" : "minutes") \(s) \(s == 1 ? "second" : "seconds") \(unitLabel)"
    }

    // MARK: - Cool-Down Prefix (internal for testing)

    static func coolDownPrefix(isActive: Bool) -> String {
        isActive ? "Walking — " : ""
    }

    // MARK: - Coach Comparison (internal for testing)

    static func coachComparisonText(
        splitIndex: Int,
        coachData: CoachData,
        enabledFields: Set<AudioCueField> = Set(AudioCueField.allCases),
        unitSystem: UnitSystem = .imperial
    ) -> String {
        var parts: [String] = []
        let splitIdx0 = splitIndex - 1
        guard splitIdx0 >= 0 else { return "" }

        // Total time vs last run
        if enabledFields.contains(.totalTimeVsLastRun),
           splitIdx0 < coachData.lastRunCumulativeSplitTimes.count {
            let delta = coachData.currentCumulativeTime - coachData.lastRunCumulativeSplitTimes[splitIdx0]
            parts.append(formatTimeDelta(delta, label: "Total time"))
        }

        // Split time vs last run
        if enabledFields.contains(.splitTimeVsLastRun),
           splitIdx0 < coachData.lastRunPerSplitTimes.count {
            let delta = coachData.currentSplitDuration - coachData.lastRunPerSplitTimes[splitIdx0]
            parts.append(formatTimeDelta(delta, label: "Split time"))
        }

        // Split pace vs last run
        if enabledFields.contains(.splitPaceVsLastRun),
           splitIdx0 < coachData.lastRunPerSplitTimes.count,
           coachData.currentSplitPaceSecondsPerMeter > 0 {
            // Derive last run's split pace: same split distance, so pace ratio = time ratio
            let lastRunSplitDuration = coachData.lastRunPerSplitTimes[splitIdx0]
            // Delta in seconds: positive = slower, negative = faster
            let delta = coachData.currentSplitDuration - lastRunSplitDuration
            parts.append(formatTimeDelta(delta, label: "Split pace"))
        }

        // Average pace vs last run
        if enabledFields.contains(.averagePaceVsLastRun),
           splitIdx0 < coachData.lastRunCumulativeSplitTimes.count {
            // Same cumulative distance → pace delta = time delta
            let delta = coachData.currentCumulativeTime - coachData.lastRunCumulativeSplitTimes[splitIdx0]
            parts.append(formatTimeDelta(delta, label: "Average pace"))
        }

        return parts.joined(separator: " ")
    }

    private static func formatTimeDelta(_ delta: Double, label: String) -> String {
        let absDelta = Int(abs(delta))
        let aheadBehind = delta <= 0 ? "faster than" : "slower than"
        return "\(label): \(absDelta) \(absDelta == 1 ? "second" : "seconds") \(aheadBehind) last run."
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioCueService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // End the background task now that speech is complete
        if !synthesizer.isSpeaking {
            endSpeechBackgroundTask()
        }

        // Keep audio session active during a run to prevent iOS from suspending
        // the app in background. Only deactivate when no run is active.
        if !synthesizer.isSpeaking, !isRunActive {
            deactivateAudioSession()
        }
    }
}
