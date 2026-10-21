#import <Foundation/Foundation.h>

#import "RevenantDocumentBrowserTypes.h"

@protocol UIDocumentBrowserViewControllerDelegate;

@protocol UIDocumentBrowserViewControllerDelegate;

@protocol UIDocumentBrowserViewControllerDelegate;
@class UTType;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@interface UIDocumentBrowserViewController : UIViewController <NSCoding>

- (instancetype)initForOpeningFilesWithContentTypes:(nullable NSArray<NSString *> *)allowedContentTypes
    NS_DESIGNATED_INITIALIZER
    API_DEPRECATED_WITH_REPLACEMENT("use initForOpeningContentTypes: instead", ios(11.0, 14.0));

- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)bundle NS_UNAVAILABLE;

@property (nullable, nonatomic, weak) id<UIDocumentBrowserViewControllerDelegate> delegate;

@property (assign, nonatomic) BOOL allowsDocumentCreation;

@property (assign, nonatomic) BOOL allowsPickingMultipleItems;

@property (readonly, copy, nonatomic) NSArray<NSString *> *allowedContentTypes
    API_DEPRECATED("allowedContentTypes is no longer supported", ios(11.0, 14.0));

@property (readonly, copy, nonatomic) NSArray<NSString *> *recentDocumentsContentTypes
    API_DEPRECATED_WITH_REPLACEMENT("use contentTypesForRecentDocuments instead", ios(11.0, 14.0));

@property (strong, nonatomic) NSArray<UIBarButtonItem *> *additionalLeadingNavigationBarButtonItems;

@property (strong, nonatomic) NSArray<UIBarButtonItem *> *additionalTrailingNavigationBarButtonItems;

- (void)revealDocumentAtURL:(NSURL *)url
             importIfNeeded:(BOOL)importIfNeeded
                 completion:(nullable void (^)(NSURL *_Nullable revealedDocumentURL,
                                               NSError *_Nullable error))completion;

- (void)importDocumentAtURL:(NSURL *)documentURL
        nextToDocumentAtURL:(NSURL *)neighbourURL
                      mode:(UIDocumentBrowserImportMode)importMode
         completionHandler:(void (^)(NSURL *_Nullable, NSError *_Nullable))completionHandler;

- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentAtURL:(NSURL *)documentURL
    API_AVAILABLE(ios(12.0)) NS_SWIFT_NAME(transitionController(forDocumentAt:));

- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentURL:(NSURL *)documentURL
    API_DEPRECATED_WITH_REPLACEMENT("transitionControllerForDocumentAtURL:", ios(11.0, 12.0));

@property (copy, nonatomic) NSArray<UIDocumentBrowserAction *> *customActions;

- (instancetype)initForOpeningContentTypes:(nullable NSArray<UTType *> *)allowedContentTypes
    API_AVAILABLE(ios(14.0));

@property (readonly, copy, nonatomic) NSArray<UTType *> *contentTypesForRecentDocuments API_AVAILABLE(ios(14.0));

@property (assign, nonatomic) BOOL shouldShowFileExtensions API_AVAILABLE(ios(13.0));

@property (copy, nonatomic) NSString *localizedCreateDocumentActionTitle API_AVAILABLE(ios(13.0));

@property (assign, nonatomic) CGFloat defaultDocumentAspectRatio API_AVAILABLE(ios(13.0));

@property (assign, nonatomic) UIDocumentBrowserUserInterfaceStyle browserUserInterfaceStyle;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
