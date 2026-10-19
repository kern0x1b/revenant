#import <Foundation/Foundation.h>

#import "CharonDocumentBrowserTypes.h"

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@protocol UIDocumentBrowserViewControllerDelegate <NSObject>

@optional

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentURLs:(NSArray<NSURL *> *)documentURLs;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)documentURLs;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL *_Nullable urlToImport, UIDocumentBrowserImportMode importMode))importHandler;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)sourceURL toDestinationURL:(NSURL *)destinationURL;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller failedToImportDocumentAtURL:(NSURL *)documentURL error:(NSError *_Nullable)error;

- (NSArray<__kindof UIActivity *> *)documentBrowser:(UIDocumentBrowserViewController *)controller applicationActivitiesForDocumentURLs:(NSArray<NSURL *> *)documentURLs;

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller willPresentActivityViewController:(UIActivityViewController *)activityViewController;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
