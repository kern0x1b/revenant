// Deliberately not <UIKit/UIKit.h>: the SDK declares this class too, and importing the umbrella
// would bring the SDK's declaration in beside the port's, so the bodies below would be added to the
// SDK's class and the port's would never be implemented. What this file needs is Foundation and
// UIViewController, the real interface of the superclass, and no document browser with it.
#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

@class UIBarButtonItem, UIDocumentBrowserAction, UIDocumentBrowserViewController;
@protocol UIDocumentBrowserViewControllerDelegate, UIViewControllerAnimatedTransitioning;

#import <CoreFoundation/CoreFoundation.h>

#import "CharonDocumentBrowserTypes.h"
#import "UIDocumentBrowserViewController.h"
#import "UIDocumentBrowserTransitionController.h"

// The document browser's own behaviour, for the five methods the 26.2 header declares on the
// controller and its transition controller. All of it is inside the application: there is no Files
// app on this release, so "the browser's own place" is the application's Documents directory and a
// document that is not there yet is brought there by the import, exactly as the header's two
// questions describe.
//
// The completion is called exactly once on every path, including when the file is missing and the
// import was not asked for, because the header's block is the only way a caller learns what happened.

@interface UIDocumentBrowserTransitionController (CharonBrowser)
+ (instancetype)charon_makeForBrowser;
@end

@interface UIDocumentBrowserViewController ()
// What initForOpeningFilesWithContentTypes: was given, and where this browser keeps what it imports.
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

// Every property is stored: the library build turns a property the compiler would synthesize on its own
// into an error (-Werror=objc-missing-property-synthesis), so each is named, with its instance variable.
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

// The designated initialiser: the browser opens the document types it is given, and an empty or nil
// list means the application's own, as the header says.
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

// The superclass's designated initialiser, which a class claiming a designated initialiser of its
// own has to override. The header marks -initWithNibName:bundle: unavailable to an application
// anyway, so a browser is only ever made through initForOpeningFilesWithContentTypes:, and this
// routes the rest of UIViewController's ways in there rather than leaving a second browser that
// opens nothing.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initForOpeningFilesWithContentTypes:nil];
}

// Where this browser keeps what it imports: the application's Documents directory, which is the only
// place on this release an application may put a document the user is shown.
// importDocumentAtURL:nextToDocumentAtURL:mode:completionHandler:, in the order the header gives:
// copy or move the document to sit beside the one named, and answer the caller with the URL it
// ended at or the error that stopped it. The completion is called exactly once on every path --
// nothing to import, nothing beside it, a failed copy, a failed move -- because the block is the
// only way a caller learns what happened.
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
    // A move that fails leaves the document where it was, so the caller is told and not left
    // believing it moved.
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

// revealDocumentAtURL:importIfNeeded:completion:, in the order the header gives: the document at
// that URL is shown, and the caller is answered with where it is. If it is not here and the caller
// asked for it to be imported, it is brought across first and the answer is where it ended; if it
// is not here and no import was asked for, the caller is told with the error the header's own
// failure is. The completion is called exactly once on every path.
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
    // The import asks for the document to sit beside itself, which puts it in the browser's own
    // directory, and the answer is where it landed rather than where it was asked from.
    [self importDocumentAtURL:url nextToDocumentAtURL:self.charonDirectory
                        mode:UIDocumentBrowserImportModeCopy
           completionHandler:^(NSURL *_Nullable imported, NSError *_Nullable error) {
        completion(imported, error);
    }];
}

// The transition that shows a document, in the 12.0 spelling the header prefers. The controller
// is aimed at this browser's own view, and its progress is this browser's, so a transition built
// from it animates the browser rather than nothing.
- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentAtURL:(NSURL *)documentURL
{
    UIDocumentBrowserTransitionController *controller =
        [UIDocumentBrowserTransitionController charon_makeForBrowser];
    controller.targetView = self.view;
    controller.loadingProgress = [self charon_progressForDocument:documentURL];
    return controller;
}

// The same question in the 11.0 spelling, which is a row of its own. It is answered by the 12.0
// one rather than by a second implementation, so the two cannot disagree.
- (UIDocumentBrowserTransitionController *)transitionControllerForDocumentURL:(NSURL *)documentURL
{
    return [self transitionControllerForDocumentAtURL:documentURL];
}

// The progress of a document being brought across, which is what a transition shows. A document
// that is not here has nothing in progress yet, so its progress is nil, as the header's nullable
// property says it can be.
- (NSProgress * _Nullable)charon_progressForDocument:(NSURL * _Nullable)documentURL
{
    if (!documentURL)
        return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentURL.path])
        return nil;
    return [NSProgress progressWithTotalUnitCount:1];
}

// Where a document imported beside `neighbour` goes: the same directory the browser keeps its own
// in, which is where its documents belong.
- (NSURL * _Nullable)charon_destinationBeside:(NSURL *)neighbour name:(NSString *)name
{
    if (!neighbour)
        return nil;
    // A neighbour that is a directory is the place itself; one that is a file contributes the
    // directory it is in. Taking the parent of a directory would put the document one level up,
    // which is where it came from and therefore no import at all.
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
    // The path the release gives for the application's Documents directory, which is where a
    // document this browser imports belongs.
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    if (documents.length)
        return [NSURL fileURLWithPath:documents isDirectory:YES];
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

@end

@implementation UIDocumentBrowserTransitionController (CharonBrowser)
// The one way the browser makes one, since the header takes -init away from an application: the
// restriction is on what an application may call, and the port is what makes the object.
+ (instancetype)charon_makeForBrowser
{
    return [super self];
}
@end
