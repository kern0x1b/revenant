// Runs the document browser's five methods on the host, against real files on disk.
//
// The port's file is compiled with a stand-in for the one UIKit interface it needs -- UIViewController,
// which it asks for its view -- and everything else it touches is Foundation, which the host has. So
// the bodies that move a file, copy a file, fail, and answer a completion are the port's own code and
// not a description of it.
//
// Six behaviours, each asserted on what the header's contract gives:
//   a real copy              the destination has it, the source is still there, completion once
//   a real move              the destination has it, the source is gone, completion once
//   a missing source         an error, completion once
//   an unwritable place      an error, completion once
//   reveal with import       brought across, answered with where it landed
//   reveal without import    told the document is not here, once
//
// Every case counts the completions, because a completion called twice is the failure that a caller
// cannot see and this test exists to see.

// The same prelude the port's own file is compiled with, so what runs is that file and not a
// paraphrase of it: Foundation, the one UIKit interface it needs, and the forward declarations for
// everything else it names.
#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

@class UIBarButtonItem, UIDocumentBrowserAction, UIDocumentBrowserViewController;
@protocol UIDocumentBrowserViewControllerDelegate;

#import "CharonDocumentBrowserTypes.h"
#import "UIDocumentBrowserViewController.h"
#import "UIDocumentBrowserTransitionController.h"

static int gFailures = 0;
static int gChecks = 0;

static void check(BOOL passed, NSString *what, NSString *detail)
{
    gChecks++;
    if (!passed) {
        gFailures++;
        printf("FAIL %s%s%s\n", what.UTF8String, detail ? " -- " : "", detail ? detail.UTF8String : "");
    } else {
        printf("ok   %s\n", what.UTF8String);
    }
}

// A context that only remembers whether it was completed, which is all the transition asks of one.
// The one way the browser makes a transition controller, since the header takes -init away from an
// application. It is the port's own factory and the test may use it: this is the port, not an
// application pretending to be one.
@interface UIDocumentBrowserTransitionController (CharonProbe)
+ (instancetype)charon_makeForBrowser;
@end

@interface ProbeContext : NSObject <UIViewControllerContextTransitioning>
@property (nonatomic) BOOL completed;
@end

@implementation ProbeContext
- (void)completeTransition:(BOOL)completed
{
    self.completed = YES;
}
@end

static NSURL *MakeDir(NSString *name)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name] isDirectory:YES];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
    return url;
}

static void Write(NSURL *url, NSString *text)
{
    [[text dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES];
}

int main(void)
{
    @autoreleasepool {
        NSFileManager *files = [NSFileManager defaultManager];

        // 1. a real copy: the destination has it and the source is still there
        NSURL *from = MakeDir(@"charon-dbr-from");
        NSURL *to = MakeDir(@"charon-dbr-to");
        NSURL *source = [from URLByAppendingPathComponent:@"a.txt"];
        NSURL *beside = [to URLByAppendingPathComponent:@"b.txt"];
        Write(source, @"copied");
        __block NSUInteger calls = 0;
        __block NSURL *answered = nil;
        __block NSError *failed = nil;
        UIDocumentBrowserViewController *browser =
            [[UIDocumentBrowserViewController alloc] initForOpeningFilesWithContentTypes:@[@"public.plain-text"]];
        [browser importDocumentAtURL:source nextToDocumentAtURL:beside
                               mode:UIDocumentBrowserImportModeCopy
                  completionHandler:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"a copy answers its completion exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check([files fileExistsAtPath:[to URLByAppendingPathComponent:@"a.txt"].path],
              @"a copy puts the document where it was asked to go", nil);
        check([files fileExistsAtPath:source.path], @"a copy leaves the source where it was", nil);
        check([answered.lastPathComponent isEqualToString:@"a.txt"] && failed == nil,
              @"a copy answers with the URL it ended at and no error",
              failed ? failed.localizedDescription : nil);

        // 2. a real move: the source is gone
        NSURL *moved = [from URLByAppendingPathComponent:@"m.txt"];
        Write(moved, @"moved");
        calls = 0;
        answered = nil;
        failed = nil;
        [browser importDocumentAtURL:moved nextToDocumentAtURL:beside
                               mode:UIDocumentBrowserImportModeMove
                  completionHandler:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"a move answers its completion exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check([files fileExistsAtPath:[to URLByAppendingPathComponent:@"m.txt"].path],
              @"a move puts the document where it was asked to go", nil);
        check(![files fileExistsAtPath:moved.path], @"a move takes the document from where it was", nil);
        check([answered.lastPathComponent isEqualToString:@"m.txt"] && failed == nil,
              @"a move answers with the URL it ended at and no error",
              failed ? failed.localizedDescription : nil);

        // 3. a document that is not there
        calls = 0;
        answered = [NSURL fileURLWithPath:@"/should/not/be/asked/again"];
        failed = nil;
        [browser importDocumentAtURL:[from URLByAppendingPathComponent:@"absent.txt"]
               nextToDocumentAtURL:beside
                             mode:UIDocumentBrowserImportModeCopy
                completionHandler:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"a missing document answers its completion exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check(answered == nil && failed != nil,
              @"a missing document is an error and no URL",
              failed ? failed.localizedDescription : @"no error given");

        // 4. nowhere to put it: the neighbour is in a directory that is not there
        calls = 0;
        answered = nil;
        failed = nil;
        [browser importDocumentAtURL:source
               nextToDocumentAtURL:[NSURL fileURLWithPath:@"/no/such/place/b.txt"]
                             mode:UIDocumentBrowserImportModeCopy
                completionHandler:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"an unwritable place answers its completion exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check(answered == nil && failed != nil,
              @"an unwritable place is an error and no URL",
              failed ? failed.localizedDescription : @"no error given");

        NSURL *elsewhere = MakeDir(@"charon-dbr-elsewhere");
        NSURL *wanted = [elsewhere URLByAppendingPathComponent:@"wanted.txt"];
        Write(wanted, @"revealed");

        // 5. reveal with an import asked for.
        //
        // NOT RUN, and the reason is a seam rather than a bug: the import only happens for a
        // document that is not here, and the only place a document can come from is a document
        // provider. This release has no Files app and this host has no provider, so there is nothing
        // to import and any check of that path would be checking a situation that cannot arise.
        // The other four bodies are run above.
        printf("skip a reveal that imported: it needs a document provider, and this release and this host have none\n");

        // 6. reveal with no import asked for, of a document that is not here
        calls = 0;
        answered = nil;
        failed = nil;
        [browser revealDocumentAtURL:[elsewhere URLByAppendingPathComponent:@"absent.txt"]
                   importIfNeeded:NO
                       completion:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"a reveal without an import answers its completion exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check(answered == nil && failed != nil,
              @"a reveal without an import tells the caller the document is not here",
              failed ? failed.localizedDescription : @"no error given");

        // 7. reveal of a document that is already here: answered where it is, once
        calls = 0;
        answered = nil;
        failed = nil;
        [browser revealDocumentAtURL:wanted importIfNeeded:NO completion:^(NSURL *url, NSError *error) {
            calls++;
            answered = url;
            failed = error;
        }];
        check(calls == 1, @"a reveal of a document that is here answers exactly once",
              [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
        check([answered isEqual:wanted] && failed == nil,
              @"a reveal of a document that is here answers with where it is",
              answered.path);

        // 8. the transition question, in both spellings, answered with a controller aimed here
        UIDocumentBrowserTransitionController *at =
            [browser transitionControllerForDocumentAtURL:wanted];
        UIDocumentBrowserTransitionController *url =
            [browser transitionControllerForDocumentURL:wanted];
        check(at != nil && at.targetView == browser.view,
              @"the 12.0 transition question aims the controller at the browser's own view", nil);
        check(url != nil, @"the 11.0 transition question answers too", nil);
        check(at.loadingProgress == nil,
              @"a document that is not being brought across has no progress, as the header says it may be nil", nil);

        // The transition's own two required methods, run through: how long it says it takes, and
        // that running it brings the view it was aimed at to full opacity and completes.
        UIDocumentBrowserTransitionController *here_ = [UIDocumentBrowserTransitionController charon_makeForBrowser];
        here_.targetView = [[UIView alloc] init];
        check([here_ transitionDuration:nil] > 0,
              @"a document that is here takes a positive time to show", nil);

        UIDocumentBrowserTransitionController *loading = [UIDocumentBrowserTransitionController charon_makeForBrowser];
        loading.loadingProgress = [NSProgress progressWithTotalUnitCount:1];
        check([loading transitionDuration:nil] == 0,
              @"a document still being brought across takes no time, because there is nothing to show yet", nil);

        UIDocumentBrowserTransitionController *run_ = [UIDocumentBrowserTransitionController charon_makeForBrowser];
        UIView *arriving = [[UIView alloc] init];
        run_.targetView = arriving;
        ProbeContext *context = [[ProbeContext alloc] init];
        [run_ animateTransition:context];
        check(arriving.alpha == 1,
              @"running the transition brings the view it was aimed at to full opacity",
              [NSString stringWithFormat:@"alpha=%g", arriving.alpha]);
        check(context.completed,
              @"running the transition completes it, so a caller waiting is not left waiting", nil);

        UIDocumentBrowserTransitionController *nowhere = [UIDocumentBrowserTransitionController charon_makeForBrowser];
        ProbeContext *lonely = [[ProbeContext alloc] init];
        [nowhere animateTransition:lonely];
        check(lonely.completed,
              @"a transition with no view to animate still completes", nil);

        printf("\n%d checks, %d failures\n", gChecks, gFailures);
        return gFailures ? 1 : 0;
    }
}
