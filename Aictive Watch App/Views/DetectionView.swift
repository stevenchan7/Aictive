//
//  DetectionView.swift
//  Aictive
//

import SwiftUI

/// The root screen — what the app is actually for. Collection sits one tap away
/// rather than beside it: they aren't peers, and end users shouldn't land in the
/// data-gathering tool by swiping.
struct DetectionView: View {
    @Bindable var vm: DetectionViewModel

    var body: some View {
        VStack(spacing: 4) {
            if vm.isDetecting {
                Image(systemName: "waveform")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.fitness)
                    .symbolEffect(.variableColor.iterative)

                Text(vm.detector.activity ?? "Listening…")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .contentTransition(.opacity)

                Text(vm.detector.activity == nil
                     ? "\(ActivityDetector.windowSize / 50)s window"
                     : vm.detector.confidence.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Stop") { vm.stop() }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
            } else {
                Image(systemName: "figure.run")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.fitness)

                Text("Aictive")
                    .font(.headline)

                Button("Detect") { vm.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.fitness)
                    .padding(.top, 4)

                NavigationLink("Collect Data", value: "collect")
                    .buttonStyle(.borderless)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 4)
        .alert("Couldn't Start", isPresented: $vm.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
