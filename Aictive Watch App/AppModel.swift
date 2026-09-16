//
//  AppModel.swift
//  Aictive
//

import Observation

/// Owns the one `Recorder` both flows share. Detection and collection must run
/// the same sensor pipeline or the model stops seeing what it was trained on —
/// sharing the instance makes that structural rather than a thing to remember.
/// It also keeps us to a single `HKHealthStore`, which HealthKit expects.
@Observable
final class AppModel {
    let recorder: Recorder
    let detection: DetectionViewModel
    let collection: WorkoutViewModel

    init() {
        let recorder = Recorder()
        self.recorder = recorder
        self.detection = DetectionViewModel(recorder: recorder)
        self.collection = WorkoutViewModel(recorder: recorder)
    }
}
