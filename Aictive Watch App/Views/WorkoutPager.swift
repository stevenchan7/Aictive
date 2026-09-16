//
//  WorkoutPager.swift
//  Aictive
//

import SwiftUI

/// One vertically-paged tab per workout type. Swiping is only available when
/// nothing is recording — changing pages mid-set would be ambiguous.
struct WorkoutPager: View {
    let vm: WorkoutViewModel

    var body: some View {
        TabView {
            ForEach(WorkoutType.allCases) { type in
                WorkoutPage(type: type) { vm.beginCountdown(type) }
            }
            StoragePage(vm: vm)
        }
        .tabViewStyle(.verticalPage)
    }
}

private struct WorkoutPage: View {
    let type: WorkoutType
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: type.symbol)
                .font(.system(size: 36))
                .foregroundStyle(type.accent)

            Text(type.title)
                .font(.headline)

            Text(type.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(type.accent)
                .padding(.top, 4)
        }
        .padding(.horizontal, 4)
        .containerBackground(type.accent.opacity(0.3).gradient, for: .tabView)
    }
}

#Preview {
    WorkoutPager(vm: WorkoutViewModel(recorder: Recorder()))
}
