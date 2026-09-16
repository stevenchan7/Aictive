//
//  SavedView.swift
//  Aictive
//

import SwiftUI

/// Confirmation that the CSV actually reached disk. Worth a screen of its own:
/// a silently-failed write is the one bug that costs you a whole session.
struct SavedView: View {
    let saved: SavedRecording
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.fitness)

            Text("Saved")
                .font(.headline)

            Text("\(saved.sampleCount) samples · \(Duration.seconds(saved.duration).formatted(.time(pattern: .minuteSecond)))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(saved.name)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(Color.fitness)
                .padding(.top, 6)
        }
        .padding(.horizontal, 4)
    }
}
