//
//  WorkoutViewModel.swift
//  Aictive
//
//  Created by Putu Steven Belva Chan on 08/09/26.
//
import Foundation
import Observation

struct SavedRecording {
    let name: String
    let sampleCount: Int
    let duration: TimeInterval
}

@Observable
class WorkoutViewModel {
    /// One enum instead of four optionals. "Counting down but also saved" and
    /// "recording with no start date" are now unrepresentable rather than
    /// merely unlikely.
    enum Phase {
        case idle
        case countingDown(WorkoutType)
        case recording(type: WorkoutType, since: Date)
        case saved(SavedRecording)
    }

    private let recorder: Recorder

    private(set) var phase: Phase = .idle
    private(set) var storedCount = 0
    private(set) var storedBytes: Int64 = 0
    var errorMessage: String?

    init(recorder: Recorder) {
        self.recorder = recorder
        // The system can end the workout session on its own. Without this the
        // recording would be saved to disk and then silently forgotten.
        recorder.onSessionEnded = { [weak self] url in
            self?.finished(url: url, samples: 0)
        }
    }

    // MARK: - State the UI reads

    /// Recomputed whenever `recorder.sampleCount` changes — about once a second.
    /// Showing the effective rate is the fastest way to spot the sensors being
    /// throttled: it should read close to 50 Hz.
    var rateSummary: String {
        let count = recorder.sampleCount
        guard case .recording(_, let since) = phase, count > 0 else { return "starting…" }
        let elapsed = Date.now.timeIntervalSince(since)
        guard elapsed > 0 else { return "starting…" }
        return "\(count) samples · \(Int((Double(count) / elapsed).rounded())) Hz"
    }

    /// Drives the error alert.
    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: - Actions

    func prepare() async {
        do {
            try await recorder.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginCountdown(_ type: WorkoutType) {
        phase = .countingDown(type)
    }

    /// Called by `CountdownView` when it reaches zero. Sensors only start here,
    /// so the hand-to-screen movement never lands in the training data.
    func countdownFinished() {
        guard case .countingDown(let type) = phase else { return }
        do {
            try recorder.startCollecting(label: type.label)
            phase = .recording(type: type, since: .now)
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func finish() {
        let samples = recorder.sampleCount   // read before stop() clears it
        do {
            let url = try recorder.stop()
            finished(url: url, samples: samples)
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func discard() {
        recorder.discard()
        phase = .idle
    }

    func dismissSaved() {
        phase = .idle
    }

    // MARK: - Stored recordings

    func refreshStorage() {
        let s = CSVStore.summary()
        storedCount = s.count
        storedBytes = s.bytes
    }

    func clearRecordings() {
        do {
            try CSVStore.deleteAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshStorage()
    }

    // MARK: - Private

    private func finished(url: URL?, samples: Int) {
        guard let url else {
            phase = .idle
            return
        }
        let duration: TimeInterval = if case .recording(_, let since) = phase {
            Date.now.timeIntervalSince(since)
        } else {
            0
        }
        phase = .saved(
            SavedRecording(name: url.lastPathComponent, sampleCount: samples, duration: duration)
        )
    }
}
