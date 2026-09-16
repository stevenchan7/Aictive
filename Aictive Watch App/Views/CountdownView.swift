//
//  CountdownView.swift
//  Aictive
//

import SwiftUI
import WatchKit

/// Three seconds of grace before the sensors start, so the first thing in every
/// file isn't your hand travelling back from the screen. Without this, every
/// recording opens with the same "reaching for a watch" motion labelled as the
/// exercise — a consistent artifact the classifier will happily learn instead.
struct CountdownView: View {
    let type: WorkoutType
    let onComplete: () -> Void

    private static let seconds = 3

    @State private var remaining = CountdownView.seconds
    @State private var sweep: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(type.accent.opacity(0.18), lineWidth: 7)

            Circle()
                .trim(from: 0, to: sweep)
                .stroke(type.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(remaining)")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(type.accent)
                    .contentTransition(.numericText(countsDown: true))

                Text(type.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 108, height: 108)
        .task { await run() }
    }

    private func run() async {
        withAnimation(.linear(duration: Double(Self.seconds))) { sweep = 0 }
        do {
            for value in stride(from: Self.seconds, through: 1, by: -1) {
                withAnimation { remaining = value }
                WKInterfaceDevice.current().play(.click)
                try await Task.sleep(for: .seconds(1))
            }
        } catch {
            return   // the view went away and `.task` cancelled us
        }
        WKInterfaceDevice.current().play(.start)
        onComplete()
    }
}
