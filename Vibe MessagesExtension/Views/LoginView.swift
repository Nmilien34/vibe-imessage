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
    @State private var isVisible = false
    @State private var logoScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
                Spacer()

                // App Logo
                VStack(spacing: VibeSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(VibeTheme.brandGradient)
                            .frame(width: 110, height: 110)
                            .vibeShadow(.xl)

                        Image(systemName: "v.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)

                    Text("Vibes")
                        .font(VibeTypography.displayLarge)
                        .foregroundColor(VibeTheme.textPrimary)
                        .tracking(-1)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)

                Text("See what your friends are up to.\nShare your vibe.")
                    .font(VibeTypography.bodyLarge)
                    .multilineTextAlignment(.center)
                    .foregroundColor(VibeTheme.textSecondary)
                    .padding(.horizontal, VibeSpacing.xxxl)
                    .opacity(isVisible ? 1 : 0)

                // Error message
                if let error = authError {
                    Text(error)
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VibeSpacing.xxxl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                // Sign in section
                VStack(spacing: VibeSpacing.md) {
                    if isAuthenticating {
                        ProgressView()
                            .tint(VibeTheme.accent)
                            .frame(height: 56)
                            .padding(.horizontal, VibeSpacing.xxxl)
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
                        .continuousCorner(VibeTheme.radiusMedium)
                        .padding(.horizontal, VibeSpacing.xxxl)
                        .vibeShadow(.md)
                    }

                    #if DEBUG
                    Button {
                        VibeHaptic.light()
                        appState.bypassLogin()
                    } label: {
                        Text("Dev: Skip Login")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                    .padding(.top, VibeSpacing.xs)
                    #endif
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 30)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.smooth.delay(0.2)) {
                isVisible = true
            }
            withAnimation(VibeAnimation.bouncy.delay(0.3)) {
                logoScale = 1.0
            }
        }
        .animation(VibeAnimation.snappy, value: isAuthenticating)
        .animation(VibeAnimation.snappy, value: authError != nil)
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        authError = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
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
                        if !appState.isAuthenticated {
                            authError = appState.error ?? "Sign in failed. Please try again."
                        }
                    }
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
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
