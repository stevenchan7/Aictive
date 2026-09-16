//
//  ContentView.swift
//  Aictive Watch App
//
//  Created by Putu Steven Belva Chan on 08/09/26.
//

import SwiftUI

struct ContentView: View {
    @State private var app = AppModel()

    var body: some View {
        NavigationStack {
            DetectionView(vm: app.detection)
                .navigationDestination(for: String.self) { _ in
                    CollectionView(vm: app.collection)
                }
        }
        .task { await app.detection.prepare() }
    }
}

#Preview {
    ContentView()
}
