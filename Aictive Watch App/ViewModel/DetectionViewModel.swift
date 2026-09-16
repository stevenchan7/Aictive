//
//  DetectionViewModel.swift
//  Aictive
//

import Foundation
import Observation

@Observable
class DetectionViewModel {
    private let recorder: Recorder
    let detector = ActivityDetector()

    var errorMessage: String?

    init(recorder: Recorder) {
        self.recorder = recorder
    }

    var isDetecting: Bool { recorder.isRecording }

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    func start() {
        detector.reset()
        do {
            try recorder.startDetecting { [weak detector] sample in
                detector?.consume(sample)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        recorder.discard()   // detection keeps nothing, so there is nothing to save
    }

    func prepare() async {
        do {
            try await recorder.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
