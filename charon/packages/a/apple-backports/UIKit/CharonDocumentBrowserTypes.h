#import <Foundation/Foundation.h>

// UIDocumentBrowserImportMode, and the two types the delegate's questions name, for a build whose
// SDK does not carry them. A 6.1.3-era SDK has no UIDocumentBrowserViewController at all, so
// something has to say what the protocol's questions refer to; this says it, in one place, with no
// condition on which SDK is in use.

@class UIDocumentBrowserViewController, UIActivity, UIActivityViewController, UIBarButtonItem,
       UIDocumentBrowserAction, UIDocumentBrowserViewControllerDelegate,
       UIDocumentBrowserTransitionController, UIViewController;

typedef NS_ENUM(NSInteger, UIDocumentBrowserUserInterfaceStyle) {
    UIDocumentBrowserUserInterfaceStyleAutomatic = 0,
    UIDocumentBrowserUserInterfaceStyleLight,
    UIDocumentBrowserUserInterfaceStyleDark,
};

typedef NS_ENUM(NSUInteger, UIDocumentBrowserImportMode) {
    UIDocumentBrowserImportModeNone,
    UIDocumentBrowserImportModeCopy,
    UIDocumentBrowserImportModeMove,
} API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
    NS_SWIFT_NAME(UIDocumentBrowserViewController.ImportMode);
