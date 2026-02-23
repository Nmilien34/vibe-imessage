#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"nickmilien.com.vibes.MessagesExtension";

/// The "VibeAccent" asset catalog color resource.
static NSString * const ACColorNameVibeAccent AC_SWIFT_PRIVATE = @"VibeAccent";

/// The "VibeBlue" asset catalog color resource.
static NSString * const ACColorNameVibeBlue AC_SWIFT_PRIVATE = @"VibeBlue";

/// The "VibeCyan" asset catalog color resource.
static NSString * const ACColorNameVibeCyan AC_SWIFT_PRIVATE = @"VibeCyan";

/// The "VibeSecondary" asset catalog color resource.
static NSString * const ACColorNameVibeSecondary AC_SWIFT_PRIVATE = @"VibeSecondary";

/// The "OnboardingSkater" asset catalog image resource.
static NSString * const ACImageNameOnboardingSkater AC_SWIFT_PRIVATE = @"OnboardingSkater";

#undef AC_SWIFT_PRIVATE
