//
//  ActivityDetector.swift
//  Aictive
//

import CoreML
import Foundation
import Observation
import os

/// Runs the trained activity classifier over a live sample stream.
enum DetectorError: Error {
    case missingChannel(String)
}

@Observable
final class ActivityDetector {

    /// MUST equal the `predictionWindowSize` the model was trained with — the
    /// generated input is a fixed 150-element vector per channel. A mismatch
    /// doesn't error, it just feeds the model garbage.
    static let windowSize = 150

    /// Size of the LSTM's carried state, from the model's input schema.
    private static let stateSize = 400

    private(set) var activity: String?
    private(set) var confidence: Double = 0
    private(set) var windowsProcessed = 0
    private(set) var errorMessage: String?

    /// Samples accumulated toward the next prediction. Non-overlapping: the
    /// model is recurrent and carries state between windows, so windows are
    /// consumed back-to-back rather than sliding one sample at a time.
    @ObservationIgnored private var window: [MotionSample] = []

    @ObservationIgnored private let model: aictive5class?
    @ObservationIgnored private var state: MLMultiArray?

    @ObservationIgnored
    private let log = Logger(subsystem: "com.steven.Aictive", category: "detector")

    init() {
        window.reserveCapacity(Self.windowSize)
        do {
            model = try aictive5class(configuration: MLModelConfiguration())
        } catch {
            model = nil
            errorMessage = "Couldn't load the model."
            log.error("model load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() {
        window.removeAll(keepingCapacity: true)
        activity = nil
        confidence = 0
        windowsProcessed = 0
        state = nil      // a new session must not inherit the last one's state
    }

    func consume(_ sample: MotionSample) {
        window.append(sample)
        guard window.count == Self.windowSize else { return }
        runModel(on: window)
        windowsProcessed += 1
        window.removeAll(keepingCapacity: true)
    }

    // MARK: - Model

    private func runModel(on window: [MotionSample]) {
        guard let model else { return }
        do {
            // One 150-element vector per feature channel, keyed by name so a
            // channel can never be silently swapped — the model's argument
            // order is alphabetical and differs from our feature order.
            var columns: [String: MLMultiArray] = [:]
            for (channel, name) in MotionSample.featureNames.enumerated() {
                let array = try MLMultiArray(shape: [NSNumber(value: Self.windowSize)],
                                             dataType: .double)
                for (row, sample) in window.enumerated() {
                    array[row] = NSNumber(value: sample.features[channel])
                }
                columns[name] = array
            }
            func column(_ name: String) throws -> MLMultiArray {
                guard let c = columns[name] else { throw DetectorError.missingChannel(name) }
                return c
            }

            let stateIn = try state ?? MLMultiArray(
                shape: [NSNumber(value: Self.stateSize)], dataType: .double
            )
            if state == nil {
                for i in 0..<Self.stateSize { stateIn[i] = 0 }
            }

            let out = try model.prediction(
                accelX: column("accelX"), accelY: column("accelY"), accelZ: column("accelZ"),
                gravX:  column("gravX"),  gravY:  column("gravY"),  gravZ:  column("gravZ"),
                pitch:  column("pitch"),  roll:   column("roll"),
                rotX:   column("rotX"),   rotY:   column("rotY"),   rotZ:   column("rotZ"),
                stateIn: stateIn
            )

            // Feed the state forward — dropping it makes the model behave as if
            // every window were the first it has ever seen.
            state = out.stateOut
            activity = out.label
            confidence = out.labelProbability[out.label] ?? 0
        } catch {
            errorMessage = "Prediction failed."
            log.error("prediction failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
