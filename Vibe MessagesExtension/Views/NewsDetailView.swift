//
//  NewsDetailView.swift
//  Vibe MessagesExtension
//
//  Created on 1/29/26.
//

import SwiftUI
import SafariServices

// MARK: - Safari View Helper (In-App Browser)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = .black
        controller.preferredControlTintColor = .white
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}

// MARK: - News Detail View
struct NewsDetailView: View {
    let newsItem: NewsItem
    let onBack: () -> Void
    let onShare: () -> Void

    @State private var showWebView = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // LAYER 1: Hero Image Background
                if let imageUrl = newsItem.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle().fill(VibeTheme.surfaceOverlay)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                } else {
                    Rectangle().fill(Color.black)
                }

                // LAYER 2: Dark Gradient Overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.9)]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // LAYER 3: Content
                VStack(alignment: .leading, spacing: 0) {

                    // HEADER (Back & Share)
                    HStack {
                        Button(action: {
                            VibeHaptic.light()
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(VibeSpacing.sm)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Spacer()

                        // Share Button
                        if let url = URL(string: newsItem.url) {
                            ShareLink(
                                item: url,
                                message: Text("Check out this vibe: \(newsItem.headline)")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(VibeSpacing.sm)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.lg)
                    .padding(.top, VibeSpacing.lg)

                    Spacer()

                    // HERO CONTENT
                    VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {

                        // Vibe Badge
                        HStack(spacing: 3) {
                            if newsItem.isJustIn {
                                Text("JUST IN")
                                    .font(VibeTypography.overline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(VibeTheme.brandGradient)
                                    .clipShape(Capsule())
                            } else {
                                Text("TRENDING")
                                    .font(VibeTypography.overline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(VibeTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }

                        // Source & Time
                        Text("\(newsItem.source.uppercased()) • \(newsItem.timeAgo.uppercased())")
                            .font(VibeTypography.overline)
                            .foregroundColor(VibeTheme.textTertiary)

                        // Headline
                        Text(newsItem.headline)
                            .font(VibeTypography.titleLarge)
                            .foregroundColor(.white)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)

                        // Vibe Score if available
                        if newsItem.vibeScore > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text("\(newsItem.vibeScore) Vibe Score")
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        // CTA Button
                        Button(action: {
                            VibeHaptic.light()
                            showWebView = true
                        }) {
                            HStack(spacing: 3) {
                                Text("Read Full Story")
                                Image(systemName: "arrow.right")
                            }
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, VibeSpacing.xs)
                            .padding(.horizontal, VibeSpacing.md)
                            .background(Color.white)
                            .continuousCorner(VibeTheme.radiusSmall)
                        }
                        .buttonStyle(VibePressStyle())
                        .padding(.top, VibeSpacing.xxxs)
                    }
                    .padding(.horizontal, VibeSpacing.md)
                    .padding(.bottom, VibeSpacing.lg)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .background(Color.black)
        // In-App Browser Sheet
        .sheet(isPresented: $showWebView) {
            if let url = URL(string: newsItem.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
