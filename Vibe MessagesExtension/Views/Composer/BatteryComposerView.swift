//
//  BatteryComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import UIKit

struct BatteryComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var batteryLevel: Int = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown

    var body: some View {
        VStack(spacing: VibeSpacing.xxxl) {
            Spacer()

            Text("Current Vibe")
                .font(VibeTypography.titleLarge)
                .foregroundColor(VibeTheme.textPrimary)

            ZStack {
                RoundedRectangle(cornerRadius: VibeTheme.radiusLarge)
                    .stroke(VibeTheme.textPrimary, lineWidth: 4)
                    .frame(width: 150, height: 250)

                RoundedRectangle(cornerRadius: 4)
                    .fill(VibeTheme.textPrimary)
                    .frame(width: 60, height: 10)
                    .offset(y: -135)

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 20)
                        .fill(batteryGradient)
                        .frame(width: 138, height: CGFloat(batteryLevel) * 2.38)
                        .animation(VibeAnimation.bouncy, value: batteryLevel)
                }
                .frame(width: 150, height: 238)
                .padding(.bottom, 6)

                Text("\(batteryLevel)%")
                    .font(VibeTypography.numericLarge)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .contentTransition(.numericText())
            }

            if batteryState == .charging {
                HStack(spacing: VibeSpacing.xxs) {
                    Image(systemName: "bolt.fill")
                    Text("Charging")
                }
                .font(VibeTypography.titleSmall)
                .foregroundColor(.yellow)
            }

            Button {
                VibeHaptic.success()
                Task { await shareBattery() }
            } label: {
                Text("Share Battery Vibe")
                    .vibeButton(.primary)
            }
            .buttonStyle(VibePressStyle())
            .padding(.horizontal, VibeSpacing.xxxl)

            Spacer()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateBattery()
        }
    }

    private func updateBattery() {
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            batteryLevel = 100
        } else {
            batteryLevel = Int(level * 100)
        }
        batteryState = UIDevice.current.batteryState
    }

    private var batteryGradient: LinearGradient {
        switch batteryLevel {
        case 0..<20:
            return LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
        case 20..<50:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
        default:
            return LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
        }
    }

    private func shareBattery() async {
        do {
            let vibe = try await appState.createVibe(
                type: .battery,
                batteryLevel: batteryLevel,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .battery, contextText: "\(batteryLevel)%")
            appState.dismissComposer()
        } catch {
            print("Error sharing battery: \(error)")
        }
    }
}
