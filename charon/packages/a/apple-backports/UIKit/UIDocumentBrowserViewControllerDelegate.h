#import <Foundation/Foundation.h>

#import "CharonDocumentBrowserTypes.h"

// UIDocumentBrowserViewControllerDelegate, as the 26.2 header declares it: nine questions, every one
// of them optional, and the two pairs of the same question under the 11.0 and the 12.0 spelling.
//
// This is a transcription, not a design. The declarations below are copied from
// `iPhoneOS26.2.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIDocumentBrowserViewController.h:142`
// and its selector list, and tests/backports/host/documentbrowser/ast_check.py compares the two from
// clang's AST: the same selector set, and optional where the header says optional. It also has a
// control, which is the only thing that makes it a check rather than a description.
//
// Why a transcription at all: the 16.4 SDK this package builds against does not carry
// UIDocumentBrowserViewController at all, so the names are not visible to a translation unit here, and
// an application compiled against the port's header links against the protocol through this
// declaration.

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@protocol UIDocumentBrowserViewControllerDelegate <NSObject>

@optional

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentURLs:(NSArray<NSURL *> *)documentURLs;

/* The 12.0 spelling of the same question. */
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)documentURLs;

/* The user asked for a new document. */
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL *_Nullable urlToImport, UIDocumentBrowserImportMode importMode))importHandler;

/* The import finished, and the document is at its destination. */
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)sourceURL toDestinationURL:(NSURL *)destinationURL;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller failedToImportDocumentAtURL:(NSURL *)documentURL error:(NSError *_Nullable)error;

/* The activities to offer for a set of documents. */
- (NSArray<__kindof UIActivity *> *)documentBrowser:(UIDocumentBrowserViewController *)controller applicationActivitiesForDocumentURLs:(NSArray<NSURL *> *)documentURLs;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller willPresentActivityViewController:(UIActivityViewController *)activityViewController;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
