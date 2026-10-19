#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

@class UIBarButtonItem, UIDocumentBrowserAction, UIDocumentBrowserViewController;
@protocol UIDocumentBrowserViewControllerDelegate, UIViewControllerAnimatedTransitioning;

#import <CoreFoundation/CoreFoundation.h>

#import "CharonDocumentBrowserTypes.h"
#import "UIDocumentBrowserViewController.h"
#import "UIDocumentBrowserTransitionController.h"

@interface UIDocumentBrowserTransitionController (CharonBrowser)
+ (instancetype)charon_makeForBrowser;
@end

@interface UIDocumentBrowserViewController ()
@property (nonatomic, copy) NSArray<NSString *> *charonAllowedContentTypes;
@property (nonatomic, copy) NSURL *charonDirectory;
- (NSURL * _Nullable)charon_documentsDirectory;
- (NSURL * _Nullable)charon_destinationBeside:(NSURL * _Nullable)neighbour
                                         name:(NSString * _Nonnull)name;
- (NSError * _Nonnull)charon_errorWithCode:(NSInteger)code
                                description:(NSString * _Nonnull)description;
- (NSProgress * _Nullable)charon_progressForDocument:(NSURL * _Nullable)documentURL;
@end

@implementation UIDocumentBrowserViewController

@synthesize delegate = _delegate;
@synthesize allowsDocumentCreation = _allowsDocumentCreation;
@synthesize allowsPickingMultipleItems = _allowsPickingMultipleItems;
@synthesize allowedContentTypes = _allowedContentTypes;
@synthesize recentDocumentsContentTypes = _recentDocumentsContentTypes;
@synthesize additionalLeadingNavigationBarButtonItems = _additionalLeadingNavigationBarButtonItems;
@synthesize additionalTrailingNavigationBarButtonItems = _additionalTrailingNavigationBarButtonItems;
@synthesize customActions = _customActions;
@synthesize browserUserInterfaceStyle = _browserUserInterfaceStyle;
@synthesize charonAllowedContentTypes = _charonAllowedContentTypes;
@synthesize charonDirectory = _charonDirectory;

- (instancetype)initForOpeningFilesWithContentTypes:(NSArray<NSString *> *)allowedContentTypes
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _charonAllowedContentTypes = [allowedContentTypes copy] ?: @[];
        _charonDirectory = [self charon_documentsDirectory];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    return [self initForOpeningFilesWithContentTypes:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initForOpeningFilesWithContentTypes:nil];
}

- (void)importDocumentAtURL:(NSURL *)documentURL
        nextToDocumentAtURL:(NSURL *)neighbourURL
                      mode:(UIDocumentBrowserImportMode)importMode
         completionHandler:(void (^)(NSURL *_Nullable, NSError *_Nullable))completionHandler
{
    if (!completionHandler)
        return;
    if (!documentURL) {
        completionHandler(nil, [self charon_errorWithCode:NSURLErrorBadURL
                                      description:@"no document to import"]);
        return;
    }
    NSFileManager *files = [NSFileManager defaultManager];
    if (![files fileExistsAtPath:documentURL.path]) {
        completionHandler(nil, [self charon_errorWithCode:NSFileNoSuchFileError
                                      description:@"the document is not there"]);
        return;
    }
    NSURL *destination = [self charon_destinationBeside:neighbourURL name:documentURL.lastPathComponent];
    if (!destination) {
        completionHandler(nil, [self charon_errorWithCode:NSFileWriteUnknownError
                                      description:@"no place to put the document"]);
        return;
    }
    BOOL ok = (importMode == UIDocumentBrowserImportModeMove)
        ? [files moveItemAtPath:documentURL.path toPath:destination.path error:NULL]
        : [files copyItemAtPath:documentURL.path toPath:destination.path error:NULL];
    if (!ok) {
        completionHandler(nil, [self charon_errorWithCode:NSFileWriteUnknownError
                                      description:@"the document could not be brought across"]);
        return;
    }
    completionHandler(destination, nil);
}

- (void)revealDocumentAtURL:(NSURL *)url
             importIfNeeded:(BOOL)importIfNeeded
                 completion:(void (^)(NSURL *_Nullable revealedDocumentURL,
                                      NSError *_Nullable error))completion
{
    if (!completion)
        return;
    if (!url) {
        completion(nil, [self charon_errorWithCode:NSURLErrorBadURL description:@"no document to show"]);
        return;
    }
    NSFileManager *files = [NSFileManager defaultManager];
    if ([files fileExistsAtPath:url.path]) {
        completion(url, nil);
        return;
    }
    if (!importIfNeeded) {
        completion(nil, [self charon_errorWithCode:NSFileNoSuchFileError
                             description:@"the document is not here and no import was asked for"]);
        return;
    }
    [self importDocumentAtURL:url nextToDocumentAtURL:self.charonDirectory
                        mode:UIDocumentBrowserImportModeCopy
           completionHandler:^(NSURL *_Nullable imported, NSError *_Nullable error) {
        completion(imported, error);
    }];
}

- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentAtURL:(NSURL *)documentURL
{
    UIDocumentBrowserTransitionController *controller =
        [UIDocumentBrowserTransitionController charon_makeForBrowser];
    controller.targetView = self.view;
    controller.loadingProgress = [self charon_progressForDocument:documentURL];
    return controller;
}

- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentURL:(NSURL *)documentURL
{
    return [self transitionControllerForDocumentAtURL:documentURL];
}

- (NSProgress * _Nullable)charon_progressForDocument:(NSURL * _Nullable)documentURL
{
    if (!documentURL)
        return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentURL.path])
        return nil;
    return [NSProgress progressWithTotalUnitCount:1];
}

- (NSURL * _Nullable)charon_destinationBeside:(NSURL *)neighbour name:(NSString *)name
{
    if (!neighbour)
        return nil;
    NSFileManager *files = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [files fileExistsAtPath:neighbour.path isDirectory:&isDirectory];
    NSString *directory = (exists && isDirectory)
        ? neighbour.path
        : [neighbour.URLByDeletingLastPathComponent path];
    if (!directory.length)
        directory = self.charonDirectory.path;
    if (!directory.length)
        return nil;
    return [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name] isDirectory:NO];
}

- (NSError * _Nonnull)charon_errorWithCode:(NSInteger)code description:(NSString *)description
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

- (NSURL * _Nullable)charon_documentsDirectory
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    if (documents.length)
        return [NSURL fileURLWithPath:documents isDirectory:YES];
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

@end

@implementation UIDocumentBrowserTransitionController (CharonBrowser)
+ (instancetype)charon_makeForBrowser
{
    return [super self];
}
@end
