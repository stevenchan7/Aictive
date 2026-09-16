//
//  CollectionView.swift
//  Aictive
//

import SwiftUI

/// The data-gathering tool. Was the root view; now lives behind a link.
struct CollectionView: View {
    @Bindable var vm: WorkoutViewModel

    var body: some View {
        Group {
            switch vm.phase {
            case .idle:
                WorkoutPager(vm: vm)
            case .countingDown(let type):
                CountdownView(type: type) { vm.countdownFinished() }
            case .recording(let type, let since):
                RecordingView(vm: vm, type: type, since: since)
            case .saved(let saved):
                SavedView(saved: saved, onDone: vm.dismissSaved)
            }
        }
        // The nav bar costs a third of the screen during a countdown or a set.
        .toolbarVisibility(isIdle ? .automatic : .hidden, for: .navigationBar)
        .alert("Couldn't Record", isPresented: $vm.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var isIdle: Bool {
        if case .idle = vm.phase { true } else { false }
    }
}
