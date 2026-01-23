//
//  LoginView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo or Icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF4D4D"), Color(hex: "FF9E4D")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(hex: "FF4D4D").opacity(0.3), radius: 15, x: 0, y: 10)
                    
                    Image(systemName: "v.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                }
                
                Text("Vibe")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(-1)
            }
            
            Text("See what your friends are up to.\nShare your vibe.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Sign in with Apple Button
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    handleSignInResult(result)
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .padding(.horizontal, 40)
            
            #if DEBUG
            Button {
                appState.bypassLogin()
            } label: {
                Text("Dev: Skip Login")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
            #endif
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let identityToken = String(data: appleIDCredential.identityToken!, encoding: .utf8)!
                let firstName = appleIDCredential.fullName?.givenName
                let lastName = appleIDCredential.fullName?.familyName
                
                Task {
                    await appState.handleAppleSignIn(
                        identityToken: identityToken,
                        firstName: firstName,
                        lastName: lastName
                    )
                }
            }
        case .failure(let error):
            print("Authentication failed: \(error.localizedDescription)")
        }
    }
}

// Helper extension for Hex Colors if not already present
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState())
    }
}
