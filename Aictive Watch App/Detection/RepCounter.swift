//
//  RepCounter.swift
//  Aictive
//

import Foundation
import Observation

/// Counts repetitions from the live sample stream.
///
/// A Schmitt trigger on one signal channel: the value has to rise above an
/// upper threshold, then fall below a lower one, before another rep can be
/// counted. The gap between the two thresholds is what stops a noisy signal
/// hovering at one level from counting dozens of reps.
///
/// Thresholds adapt to the last six seconds rather than being fixed, so the
/// counter follows a set that gets slower or shallower as you tire.
///
/// Which channel carries the rep depends on the exercise, and the two families
/// are near-opposites. Exercises that *rotate* the wrist (lat pulldown, seated
/// row, push-ups) show up in gravity and gyroscope. Exercises that *translate*
/// the hand up and down (chest press, lunges) barely rotate it at all, and need
/// vertical velocity instead — measured across the recorded sets, chest press
/// scores 0.25 on acceleration magnitude but 0.72 on vertical velocity, while
/// push-ups score 0.52 on gravity and 0.02 on vertical velocity.
@Observable
final class RepCounter {

    private(set) var reps = 0

    /// False for exercises with no reliable wrist signature — the UI should
    /// show nothing rather than a number that would be wrong.
    private(set) var isCountable = false

    private enum Channel {
        /// A value read straight off the sample.
        case direct(KeyPath<MotionSample, Double>)
        /// Vertical velocity: acceleration projected onto the gravity axis and
        /// integrated with a leak. True integration drifts without bound — the
        /// leak turns it into a band-pass filter that recovers the oscillating
        /// part of the motion and discards the accumulating error. This is what
        /// makes "the hand moved up, then down" measurable at all; position
        /// itself is not recoverable from an IMU.
        case verticalVelocity(decay: Double)
    }

    private struct Profile {
        let channel: Channel
        /// Shortest believable rep. Anything faster is noise, not a rep.
        let minPeriod: TimeInterval
        /// Below this much variation we're not moving enough to be exercising.
        let minAmplitude: Double
    }

    private static let profiles: [String: Profile] = [
        // Rotation-led: the wrist turns through the movement.
        "pushup":     Profile(channel: .direct(\.gravY),         minPeriod: 1.5, minAmplitude: 0.02),
        "latpuldown": Profile(channel: .direct(\.gravY),         minPeriod: 2.0, minAmplitude: 0.02),
        "seatedrow":  Profile(channel: .direct(\.gyroMagnitude), minPeriod: 1.5, minAmplitude: 0.10),
        // Translation-led: the hand travels while the wrist holds its angle.
        "chestpress": Profile(channel: .verticalVelocity(decay: 0.99), minPeriod: 2.0, minAmplitude: 0.015),
        "lunge":      Profile(channel: .verticalVelocity(decay: 0.99), minPeriod: 2.0, minAmplitude: 0.015),
    ]

    private static let windowSize = 300      // 6s at 50 Hz
    private static let smoothing = 0.125     // EMA over roughly 0.3s
    private static let bandWidth = 0.40      // thresholds at ±0.40 standard deviations

    @ObservationIgnored private var profile: Profile?
    @ObservationIgnored private var activity: String?

    // Rolling mean and standard deviation, kept incrementally so each sample
    // costs a handful of arithmetic rather than a pass over the buffer.
    @ObservationIgnored private var buffer: [Double] = []
    @ObservationIgnored private var sum = 0.0
    @ObservationIgnored private var sumOfSquares = 0.0

    @ObservationIgnored private var smoothed: Double?
    /// Running state for `.verticalVelocity`.
    @ObservationIgnored private var velocity = 0.0
    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var isHigh = false
    @ObservationIgnored private var lastRepAt: TimeInterval = -.greatestFiniteMagnitude

    init() {
        buffer.reserveCapacity(Self.windowSize)
    }

    func reset() {
        reps = 0
        isCountable = false
        profile = nil
        activity = nil
        clearSignalState()
    }

    /// - Parameter activity: the classifier's current label, or nil before the
    ///   first window has been classified.
    func consume(_ sample: MotionSample, activity: String?) {
        if activity != self.activity {
            self.activity = activity
            profile = activity.flatMap { Self.profiles[$0] }
            isCountable = profile != nil
            reps = 0                 // a new exercise starts a new set
            clearSignalState()
        }

        guard let profile else { return }

        // Light smoothing. Raw 50 Hz data crosses any threshold several times
        // per rep from sensor noise alone.
        let raw = signal(for: sample, channel: profile.channel)
        let value = smoothed.map { $0 + Self.smoothing * (raw - $0) } ?? raw
        smoothed = value

        buffer.append(value)
        sum += value
        sumOfSquares += value * value
        if buffer.count > Self.windowSize {
            let old = buffer.removeFirst()
            sum -= old
            sumOfSquares -= old * old
        }

        // Wait for a few seconds of history before trusting the statistics.
        guard buffer.count >= Self.windowSize / 2 else { return }

        let count = Double(buffer.count)
        let mean = sum / count
        let deviation = max(sumOfSquares / count - mean * mean, 0).squareRoot()

        guard deviation >= profile.minAmplitude else {
            isHigh = false          // resting between sets
            return
        }

        let upper = mean + Self.bandWidth * deviation
        let lower = mean - Self.bandWidth * deviation

        if !isHigh, value > upper {
            isHigh = true
            // `timestamp` is the sensor's own clock, so this stays correct even
            // if delivery jitters.
            if sample.timestamp - lastRepAt >= profile.minPeriod {
                reps += 1
                lastRepAt = sample.timestamp
            }
        } else if isHigh, value < lower {
            isHigh = false
        }
    }

    private func signal(for sample: MotionSample, channel: Channel) -> Double {
        switch channel {
        case .direct(let path):
            return sample[keyPath: path]

        case .verticalVelocity(let decay):
            // Component of user acceleration along gravity — i.e. straight up
            // and down, whichever way the watch happens to be facing.
            let g = (sample.gravX, sample.gravY, sample.gravZ)
            let magnitude = (g.0 * g.0 + g.1 * g.1 + g.2 * g.2).squareRoot()
            guard magnitude > 0 else { return velocity }
            let vertical = (sample.accelX * g.0 + sample.accelY * g.1 + sample.accelZ * g.2) / magnitude

            // Use the sensor's own clock: delivery jitters, and integrating
            // against a wrong dt skews the result.
            let dt = lastTimestamp.map { min(max(sample.timestamp - $0, 0), 0.1) } ?? 0.02
            lastTimestamp = sample.timestamp

            velocity = velocity * decay + vertical * dt
            return velocity
        }
    }

    private func clearSignalState() {
        buffer.removeAll(keepingCapacity: true)
        sum = 0
        sumOfSquares = 0
        smoothed = nil
        velocity = 0
        lastTimestamp = nil
        isHigh = false
        lastRepAt = -.greatestFiniteMagnitude
    }
}
