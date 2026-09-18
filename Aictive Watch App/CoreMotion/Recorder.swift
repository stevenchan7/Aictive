//
//  Recorder.swift
//  Aictive
//
//  Created by Putu Steven Belva Chan on 08/09/26.
//
import CoreMotion
import Foundation
import HealthKit

struct MotionSample {
    let timestamp: TimeInterval          // seconds since device boot, NOT wall clock
    let accelX, accelY, accelZ: Double   // userAcceleration, in g (gravity removed)
    let rotX, rotY, rotZ: Double         // rotationRate, rad/s (gyroscope)
    let gravX, gravY, gravZ: Double      // gravity vector, in g (tells you orientation)
    let roll, pitch, yaw: Double         // attitude, rad
}

// Data mapping
extension MotionSample {
    init(_ d: CMDeviceMotion) {
        timestamp = d.timestamp
        accelX = d.userAcceleration.x
        accelY = d.userAcceleration.y
        accelZ = d.userAcceleration.z
        rotX = d.rotationRate.x
        rotY = d.rotationRate.y
        rotZ = d.rotationRate.z
        gravX = d.gravity.x
        gravY = d.gravity.y
        gravZ = d.gravity.z
        roll = d.attitude.roll
        pitch = d.attitude.pitch
        yaw = d.attitude.yaw
    }
}

// The model's input. This order MUST match the `featureColumns` you pass to
// Create ML, and must never change once a model is trained against it.
extension MotionSample {
    static let featureNames = ["accelX", "accelY", "accelZ",
                               "rotX", "rotY", "rotZ",
                               "gravX", "gravY", "gravZ",
                               "roll", "pitch"]          // yaw excluded: drifts

    /// Overall rotation rate, independent of which way the wrist is facing.
    /// The clearest rep signal for exercises where the arm sweeps rather than
    /// tilts — seated row, for instance.
    var gyroMagnitude: Double {
        (rotX * rotX + rotY * rotY + rotZ * rotZ).squareRoot()
    }

    var features: [Double] {
        [accelX, accelY, accelZ, rotX, rotY, rotZ, gravX, gravY, gravZ, roll, pitch]
    }
}

// CSV formatting — happens once at export, never in the sensor handler
extension MotionSample {
    static let csvHeader = "timestamp,label,recordingId,accelX,accelY,accelZ,rotX,rotY,rotZ,gravX,gravY,gravZ,roll,pitch,yaw"

    func csvRow(label: String, recordingId: String) -> String {
        let time = String(format: "%.6f", timestamp)
        let values = String(
            format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f",
            accelX, accelY, accelZ,
            rotX, rotY, rotZ,
            gravX, gravY, gravZ,
            roll, pitch, yaw
        )
        return "\(time),\(label),\(recordingId),\(values)"
    }
}

enum RecorderError: Error {
    case deviceMotionUnavailable
    case healthDataUnavailable
    case alreadyRecording(label: String)
}

extension RecorderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .deviceMotionUnavailable: "This device has no motion sensors."
        case .healthDataUnavailable: "HealthKit isn't available on this device."
        case .alreadyRecording(let label): "Already recording \"\(label)\"."
        }
    }
}

@Observable
class Recorder: NSObject {
    private let sampleRate = 50.0      // Hz
    private let reserveMinutes = 10.0  // how much buffer to pre-allocate

    // properties aren't tracked by @Observable
    private let motion = CMMotionManager()
    private let healthStore = HKHealthStore()

    // These change constantly and nothing in the UI reads them — keep them out
    // of the observation machinery so `samples.append` stays a plain array write.
    /// What the sensor stream is being used for. Collection accumulates samples
    /// to disk; detection streams them straight to a consumer and keeps nothing.
    private enum Mode {
        case idle
        case collecting
        case detecting(sink: (MotionSample) -> Void)
    }

    @ObservationIgnored private var mode: Mode = .idle
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var label = ""
    @ObservationIgnored private var recordingId = ""
    @ObservationIgnored private var samples: [MotionSample] = []

    /// Called when the *system* ends the session rather than the user, so the
    /// data isn't silently thrown away.
    @ObservationIgnored var onSessionEnded: ((URL) -> Void)?

    /// The two properties the UI observes.
    private(set) var isRecording = false

    /// Updated roughly once a second, not once per sample — the UI must never
    /// be invalidated at 50 Hz.
    private(set) var sampleCount = 0

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw RecorderError.healthDataUnavailable }
        try await healthStore.requestAuthorization(
            toShare: [HKQuantityType.workoutType()],
            read: []
        )
    }

    /// Record to disk, for gathering training data.
    func startCollecting(label: String) throws {
        try preflight()

        self.label = label
        self.recordingId = UUID().uuidString
        self.mode = .collecting

        samples.removeAll(keepingCapacity: true)
        samples.reserveCapacity(Int(sampleRate * 60 * reserveMinutes))
        sampleCount = 0

        try beginSensing()
    }

    /// Stream samples to a consumer without keeping any. Same sensor pipeline as
    /// collection — that's the point, the model must see exactly what it was
    /// trained on.
    func startDetecting(onSample: @escaping (MotionSample) -> Void) throws {
        try preflight()
        self.mode = .detecting(sink: onSample)
        try beginSensing()
    }

    private func preflight() throws {
        guard !isRecording else { throw RecorderError.alreadyRecording(label: self.label) }
        guard motion.isDeviceMotionAvailable else { throw RecorderError.deviceMotionUnavailable }
    }

    private func beginSensing() throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        // Start a workout session to keep the app alive and the sensors running
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        session.delegate = self
        session.startActivity(with: Date())
        self.session = session

        // Fixed rate: how often to trigger an update. This is a hint, not a
        // guarantee — that's why each sample carries its own timestamp.
        motion.deviceMotionUpdateInterval = 1.0 / sampleRate
        motion.startDeviceMotionUpdates(to: .main) { [weak self] dm, error in
            guard let self, let dm, error == nil else { return }
            let sample = MotionSample(dm)

            switch self.mode {
            case .collecting:
                self.samples.append(sample)
                if self.samples.count % Int(self.sampleRate) == 0 {
                    self.sampleCount = self.samples.count
                }
            case .detecting(let sink):
                sink(sample)
            case .idle:
                break
            }
        }

        isRecording = true
    }

    /// Stops recording, writes the CSV, and returns its URL.
    /// Safe to call when not recording — returns nil.
    @discardableResult
    func stop() throws -> URL? {
        guard isRecording else { return nil }

        motion.stopDeviceMotionUpdates()   // 1. sensors off first
        isRecording = false

        // Detection keeps nothing, so there is no file to write.
        guard case .collecting = mode else {
            teardown()
            return nil
        }

        let csvString = makeCSV()          // 2. format while the session still protects us

        defer { teardown() }               // 3. runs even if the write throws

        return try CSVStore.save(csvString, label: label)
    }

    /// Stops recording and throws the samples away. For a fumbled set you don't
    /// want polluting the training data.
    func discard() {
        guard isRecording else { return }
        motion.stopDeviceMotionUpdates()
        isRecording = false
        teardown()
    }

    private func teardown() {
        mode = .idle
        samples.removeAll(keepingCapacity: true)
        sampleCount = 0
        label = ""
        recordingId = ""

        session?.delegate = nil            // stopping on purpose — don't call ourselves back
        session?.end()                     // give up extended runtime last
        session = nil
    }

    private func makeCSV() -> String {
        var csv = MotionSample.csvHeader + "\n"
        csv.reserveCapacity(samples.count * 160)
        for sample in samples {
            csv += sample.csvRow(label: label, recordingId: recordingId) + "\n"
        }
        return csv
    }
}

// The system can end a workout session without being asked — low power mode, an
// error, another app taking over. Without this, motion updates would keep
// running with nothing keeping the app alive.
extension Recorder: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended || toState == .stopped else { return }
        Task { @MainActor in self.finishFromSystem() }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in self.finishFromSystem() }
    }
}

extension Recorder {
    fileprivate func finishFromSystem() {
        let url = try? stop()
        if let url { onSessionEnded?(url) }
    }
}
