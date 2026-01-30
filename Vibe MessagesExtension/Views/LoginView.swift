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
    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        ZStack {
            // Background that receives touches
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

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

                    Text("Vibes")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(-1)
                }

                Text("See what your friends are up to.\nShare your vibe.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)

                // Error message
                if let error = authError {
                    Text(error)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                Spacer()

                // Sign in with Apple Button
                if isAuthenticating {
                    ProgressView()
                        .frame(height: 56)
                        .padding(.horizontal, 40)
                } else {
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
                }

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
        }
        .animation(.easeInOut(duration: 0.2), value: isAuthenticating)
        .animation(.easeInOut(duration: 0.2), value: authError)
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        authError = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Safely unwrap identity token - this is critical!
                guard let tokenData = appleIDCredential.identityToken,
                      let identityToken = String(data: tokenData, encoding: .utf8) else {
                    authError = "Could not get identity token. Please try again."
                    print("Authentication failed: Could not get identity token")
                    return
                }

                let firstName = appleIDCredential.fullName?.givenName
                let lastName = appleIDCredential.fullName?.familyName

                isAuthenticating = true

                Task {
                    await appState.handleAppleSignIn(
                        identityToken: identityToken,
                        firstName: firstName,
                        lastName: lastName
                    )

                    await MainActor.run {
                        isAuthenticating = false
                        // Check if there was an error from the API
                        if !appState.isAuthenticated {
                            authError = appState.error ?? "Sign in failed. Please try again."
                        }
                    }
                }
            }
        case .failure(let error):
            // User cancelled or other Apple Sign In error
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                // Only show error if not user-cancelled
                authError = "Sign in failed: \(error.localizedDescription)"
            }
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
