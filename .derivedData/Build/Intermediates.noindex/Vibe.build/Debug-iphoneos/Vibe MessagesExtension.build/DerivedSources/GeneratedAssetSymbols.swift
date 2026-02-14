import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "VibeAccent" asset catalog color resource.
    static let vibeAccent = DeveloperToolsSupport.ColorResource(name: "VibeAccent", bundle: resourceBundle)

    /// The "VibeBlue" asset catalog color resource.
    static let vibeBlue = DeveloperToolsSupport.ColorResource(name: "VibeBlue", bundle: resourceBundle)

    /// The "VibeCyan" asset catalog color resource.
    static let vibeCyan = DeveloperToolsSupport.ColorResource(name: "VibeCyan", bundle: resourceBundle)

    /// The "VibeSecondary" asset catalog color resource.
    static let vibeSecondary = DeveloperToolsSupport.ColorResource(name: "VibeSecondary", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "OnboardingSkater" asset catalog image resource.
    static let onboardingSkater = DeveloperToolsSupport.ImageResource(name: "OnboardingSkater", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "VibeAccent" asset catalog color.
    static var vibeAccent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vibeAccent)
#else
        .init()
#endif
    }

    /// The "VibeBlue" asset catalog color.
    static var vibeBlue: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vibeBlue)
#else
        .init()
#endif
    }

    /// The "VibeCyan" asset catalog color.
    static var vibeCyan: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vibeCyan)
#else
        .init()
#endif
    }

    /// The "VibeSecondary" asset catalog color.
    static var vibeSecondary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vibeSecondary)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "VibeAccent" asset catalog color.
    static var vibeAccent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vibeAccent)
#else
        .init()
#endif
    }

    /// The "VibeBlue" asset catalog color.
    static var vibeBlue: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vibeBlue)
#else
        .init()
#endif
    }

    /// The "VibeCyan" asset catalog color.
    static var vibeCyan: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vibeCyan)
#else
        .init()
#endif
    }

    /// The "VibeSecondary" asset catalog color.
    static var vibeSecondary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vibeSecondary)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "VibeAccent" asset catalog color.
    static var vibeAccent: SwiftUI.Color { .init(.vibeAccent) }

    /// The "VibeBlue" asset catalog color.
    static var vibeBlue: SwiftUI.Color { .init(.vibeBlue) }

    /// The "VibeCyan" asset catalog color.
    static var vibeCyan: SwiftUI.Color { .init(.vibeCyan) }

    /// The "VibeSecondary" asset catalog color.
    static var vibeSecondary: SwiftUI.Color { .init(.vibeSecondary) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "VibeAccent" asset catalog color.
    static var vibeAccent: SwiftUI.Color { .init(.vibeAccent) }

    /// The "VibeBlue" asset catalog color.
    static var vibeBlue: SwiftUI.Color { .init(.vibeBlue) }

    /// The "VibeCyan" asset catalog color.
    static var vibeCyan: SwiftUI.Color { .init(.vibeCyan) }

    /// The "VibeSecondary" asset catalog color.
    static var vibeSecondary: SwiftUI.Color { .init(.vibeSecondary) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "OnboardingSkater" asset catalog image.
    static var onboardingSkater: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .onboardingSkater)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "OnboardingSkater" asset catalog image.
    static var onboardingSkater: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .onboardingSkater)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

