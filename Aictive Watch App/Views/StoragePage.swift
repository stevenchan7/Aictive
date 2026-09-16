//
//  StoragePage.swift
//  Aictive
//

import SwiftUI

/// Last page of the pager. Exists so you can see what's on the watch without
/// downloading it, and clear it once a download has been verified — every pull
/// re-transfers the whole folder, so this is what keeps transfers quick.
struct StoragePage: View {
    let vm: WorkoutViewModel

    @State private var confirming = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .font(.system(size: 26))
                .foregroundStyle(Color.slate)

            Text("^[\(vm.storedCount) recording](inflect: true)")
                .font(.headline)

            Text(vm.storedBytes.formatted(.byteCount(style: .file)))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Clear All", role: .destructive) { confirming = true }
                .buttonStyle(.bordered)
                .disabled(vm.storedCount == 0)
                .padding(.top, 6)
        }
        .padding(.horizontal, 4)
        .containerBackground(Color.slate.opacity(0.25).gradient, for: .tabView)
        .onAppear { vm.refreshStorage() }
        .confirmationDialog(
            "Delete all recordings?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { vm.clearRecordings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Download them first — this can't be undone.")
        }
    }
}
