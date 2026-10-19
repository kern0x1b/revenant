#import <Foundation/Foundation.h>

#import "CharonDocumentBrowserTypes.h"

// The delegate property below names this protocol. Declared here as a forward declaration and not
// by importing the umbrella: UIDocumentBrowserTransitionController.h in this chain re-declares the
// class properties the SDK 16.4 UIDocumentBrowserViewController.h already declares, and pulling
// that umbrella in makes both visible at once.
@protocol UIDocumentBrowserViewControllerDelegate;

// The delegate property below names this protocol. Declared here as a forward declaration and not
// by importing the umbrella: UIDocumentBrowserTransitionController.h in this chain re-declares the
// class properties the SDK 16.4 UIDocumentBrowserViewController.h already declares, and pulling
// that umbrella in makes both visible at once.
@protocol UIDocumentBrowserViewControllerDelegate;

// The delegate property below names this protocol. Declared here as a forward declaration and not
// by importing the umbrella: UIDocumentBrowserTransitionController.h in this chain re-declares the
// class properties the SDK 16.4 UIDocumentBrowserViewController.h already declares, and pulling
// that umbrella in makes both visible at once.
@protocol UIDocumentBrowserViewControllerDelegate;

// UIDocumentBrowserViewController, as the 26.2 header declares it, and only the members that arrived
// in iOS 11 and 12 -- the ones from 13.0 and later (activeDocumentCreationIntent,
// contentTypesForRecentDocuments, shouldShowFileExtensions, localizedCreateDocumentActionTitle,
// defaultDocumentAspectRatio, initForOpeningContentTypes:) are not this port's business, and carrying
// them would claim rows this family does not contain.
//
// A transcription, like the delegate protocol and the transition controller beside it, and for the
// same reason: a 6.1.3-era SDK has no document browser at all. tests/backports/host/documentbrowser/
// ast_check.py compares this against the header with the same AST reading it uses for the other two,
// reading each property's type and attributes and each method's selector by mangledName, with a
// control per family and a mutant per default.
//
// The umbrella is deliberately not imported: the SDK declares this class too, and importing it would
// bring the SDK's copy in beside this one. What this header names is what a translation unit reading
// it must have forward declarations for, and the check's does.

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@interface UIDocumentBrowserViewController : UIViewController <NSCoding>

/* Open the files the user picks. The types allowed are the ones named, or the application's own when
 * none are. */
- (instancetype)initForOpeningFilesWithContentTypes:(nullable NSArray<NSString *> *)allowedContentTypes
    NS_DESIGNATED_INITIALIZER
    API_DEPRECATED_WITH_REPLACEMENT("use initForOpeningContentTypes: instead", ios(11.0, 14.0));

/* The designated initialiser is a designated one, and the nib one is not available. */
- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)bundle NS_UNAVAILABLE;

@property (nullable, nonatomic, weak) id<UIDocumentBrowserViewControllerDelegate> delegate;

/* Whether the user may create a document from here. */
@property (assign, nonatomic) BOOL allowsDocumentCreation;

/* Whether more than one document may be picked at a time. */
@property (assign, nonatomic) BOOL allowsPickingMultipleItems;

/* The document types this browser opens. */
@property (readonly, copy, nonatomic) NSArray<NSString *> *allowedContentTypes
    API_DEPRECATED("allowedContentTypes is no longer supported", ios(11.0, 14.0));

/* The document types the recents list holds. */
@property (readonly, copy, nonatomic) NSArray<NSString *> *recentDocumentsContentTypes
    API_DEPRECATED_WITH_REPLACEMENT("use contentTypesForRecentDocuments instead", ios(11.0, 14.0));

/* The buttons added before the browser's own. */
@property (strong, nonatomic) NSArray<UIBarButtonItem *> *additionalLeadingNavigationBarButtonItems;

/* The buttons added after the browser's own. */
@property (strong, nonatomic) NSArray<UIBarButtonItem *> *additionalTrailingNavigationBarButtonItems;

/* Show a document, importing it first if it is not already here. */
- (void)revealDocumentAtURL:(NSURL *)url
             importIfNeeded:(BOOL)importIfNeeded
                 completion:(nullable void (^)(NSURL *_Nullable revealedDocumentURL,
                                               NSError *_Nullable error))completion;

/* Import a document beside another one. */
- (void)importDocumentAtURL:(NSURL *)documentURL
        nextToDocumentAtURL:(NSURL *)neighbourURL
                      mode:(UIDocumentBrowserImportMode)importMode
         completionHandler:(void (^)(NSURL *_Nullable, NSError *_Nullable))completionHandler;

/* The transition that shows a document, in the 12.0 spelling. */
- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentAtURL:(NSURL *)documentURL
    API_AVAILABLE(ios(12.0)) NS_SWIFT_NAME(transitionController(forDocumentAt:));

/* The same transition in the 11.0 spelling, which is two rows and not one. */
- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentURL:(NSURL *)documentURL
    API_DEPRECATED_WITH_REPLACEMENT("transitionControllerForDocumentAtURL:", ios(11.0, 12.0));

/* The actions the user may take on a document. */
@property (copy, nonatomic) NSArray<UIDocumentBrowserAction *> *customActions;

/* How the browser looks. */
@property (assign, nonatomic) UIDocumentBrowserUserInterfaceStyle browserUserInterfaceStyle;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
