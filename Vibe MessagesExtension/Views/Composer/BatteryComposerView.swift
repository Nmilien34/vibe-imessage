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
        VStack(spacing: 40) {
            Spacer()
            
            Text("Current Vibe")
                .font(.title2)
                .fontWeight(.bold)
            
            ZStack {
                // Battery shape
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary, lineWidth: 4)
                    .frame(width: 150, height: 250)
                
                // Battery Cap
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary)
                    .frame(width: 60, height: 10)
                    .offset(y: -135)
                
                // Fill
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 20)
                        .fill(batteryColor)
                        .frame(width: 138, height: CGFloat(batteryLevel) * 2.38)
                        .animation(.spring(), value: batteryLevel)
                }
                .frame(width: 150, height: 238)
                .padding(.bottom, 6)
                
                // Percentage Text
                Text("\(batteryLevel)%")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            
            if batteryState == .charging {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Charging")
                }
                .font(.headline)
                .foregroundColor(.yellow)
            }
            
            Button {
                Task {
                    await shareBattery()
                }
            } label: {
                Text("Share Battery Vibe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(batteryColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateBattery()
        }
    }
    
    private func updateBattery() {
        let level = UIDevice.current.batteryLevel
        // Simulator returns -1.0 so we mock it if needed
        if level < 0 {
            batteryLevel = 100
        } else {
            batteryLevel = Int(level * 100)
        }
        batteryState = UIDevice.current.batteryState
    }
    
    private var batteryColor: Color {
        switch batteryLevel {
        case 0..<20: return .red
        case 20..<50: return .yellow
        default: return .green
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
