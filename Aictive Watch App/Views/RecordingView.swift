//
//  RecordingView.swift
//  Aictive
//

import SwiftUI

struct RecordingView: View {
    /// `vm` is read only for `rateSummary`, so the once-a-second sample update
    /// invalidates this view and nothing above it.
    let vm: WorkoutViewModel
    let type: WorkoutType
    let since: Date

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(type.accent)
                    .symbolEffect(.pulse)

                Text(type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // A self-updating timer. No Timer, no @State, no view invalidation
            // from our side — the system redraws just this text.
            Text(since, style: .timer)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .foregroundStyle(type.accent)

            Text(vm.rateSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Button("Finish") { vm.finish() }
                .buttonStyle(.borderedProminent)
                .tint(type.accent)
                .padding(.top, 6)

            Button("Discard", role: .destructive) { vm.discard() }
                .buttonStyle(.borderless)
                .font(.caption2)
        }
        .padding(.horizontal, 4)
    }
}
