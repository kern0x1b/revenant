#import <Foundation/Foundation.h>

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
