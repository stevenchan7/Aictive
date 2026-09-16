//
//  WorkoutType.swift
//  Aictive
//

import SwiftUI

enum WorkoutType: String, CaseIterable, Identifiable {
    // Exercises — what the classifier should recognise.
    case pushUp = "pushup"
    case squat = "squat"
    case lunge = "lunge"

    // Background classes — everything the classifier must NOT mistake for an
    // exercise. Kept as three labels rather than one "null" so they can be
    // merged at training time; a merged label can never be split back apart.
    case sitting
    case walking
    case gesture

    var id: Self { self }

    /// The value written to the CSV `label` column. Keep these lowercase and
    /// stable — changing one splits your training data into two classes.
    var label: String { rawValue }

    enum Kind { case exercise, background }

    var kind: Kind {
        switch self {
        case .pushUp, .squat, .lunge: .exercise
        case .sitting, .walking, .gesture: .background
        }
    }

    /// Background classes are deliberately not green. Picking the wrong tab is
    /// the cheapest mistake to make and the most expensive to find later.
    var accent: Color {
        switch kind {
        case .exercise: .fitness
        case .background: .slate
        }
    }

    var title: String {
        switch self {
        case .pushUp: "Push Up"
        case .squat: "Squat"
        case .lunge: "Lunge"
        case .sitting: "Sitting"
        case .walking: "Walking"
        case .gesture: "Gestures"
        }
    }

    var hint: String {
        switch self {
        case .pushUp: "Chest to floor"
        case .squat: "Hips below knees"
        case .lunge: "Alternate legs"
        case .sitting: "Still, hands resting"
        case .walking: "Normal pace"
        case .gesture: "Talk, scratch, reach"
        }
    }

    var symbol: String {
        switch self {
        case .pushUp: "figure.core.training"
        case .squat: "figure.strengthtraining.traditional"
        case .lunge: "figure.strengthtraining.functional"
        case .sitting: "figure.seated.side"
        case .walking: "figure.walk"
        case .gesture: "hand.wave"
        }
    }
}

extension Color {
    /// Roughly the Apple Fitness exercise-ring green.
    static let fitness = Color(red: 0.58, green: 0.92, blue: 0.16)
    /// Muted tone for non-workout classes.
    static let slate = Color(red: 0.56, green: 0.62, blue: 0.66)
}
