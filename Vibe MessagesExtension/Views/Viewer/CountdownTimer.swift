//
//  CountdownTimer.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import Combine

struct CountdownTimer: View {
    let expiresAt: Date
    @State private var timeRemaining: TimeInterval = 0
    @State private var isVisible = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(formattedTime)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(urgencyColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onAppear {
            updateTimeRemaining()
            withAnimation(.easeIn(duration: 0.4)) {
                isVisible = true
            }
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = max(0, expiresAt.timeIntervalSinceNow)
    }

    private var formattedTime: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private var urgencyColor: Color {
        if timeRemaining < 300 { // Less than 5 minutes
            return .red
        } else if timeRemaining < 3600 { // Less than 1 hour
            return .orange
        } else {
            return .white
        }
    }
}

// MARK: - Progress Ring Timer
struct ProgressRingTimer: View {
    let expiresAt: Date
    let createdAt: Date
    let size: CGFloat

    @State private var progress: Double = 1.0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: size, height: size)
        .onAppear {
            updateProgress()
        }
        .onReceive(timer) { _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        let totalDuration = expiresAt.timeIntervalSince(createdAt)
        let remaining = max(0, expiresAt.timeIntervalSinceNow)
        progress = remaining / totalDuration
    }

    private var progressColor: Color {
        if progress < 0.1 {
            return .red
        } else if progress < 0.25 {
            return .orange
        } else {
            return .white
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            CountdownTimer(expiresAt: Date().addingTimeInterval(3600))
            CountdownTimer(expiresAt: Date().addingTimeInterval(300))
            CountdownTimer(expiresAt: Date().addingTimeInterval(60))

            ProgressRingTimer(
                expiresAt: Date().addingTimeInterval(3600),
                createdAt: Date().addingTimeInterval(-20 * 3600),
                size: 40
            )
        }
    }
}
