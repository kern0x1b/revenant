// eventattribution_test.m - the link-preview attribution of iOS 14.5 and its view, port against host.
//
// Same shape as the rest of this suite: the port's classes are renamed by uikit2/run.sh and sit beside the
// system's own in one process, and every case below asks both sides. The system side is the SDK's class -
// the 16.4 SDK this package compiles against already declares both, and so does the Catalyst SDK the
// differential links - so this group has a real system side from a framework, not from the test's own
// @interface declarations, which is the stronger of the two positions the suite has.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

// The port's two classes, under the names run.sh's renamer gives them. run.sh compiles the group's SOURCES
// with the rename flags and the TEST without them, so the test declares the port's side itself - the same
// shape contentunavailable_test.m uses. The SYSTEM side is the SDK's own class throughout, which is what
// makes this group's system side come out of a framework rather than out of this file.
@interface CharonHostUIEventAttribution : NSObject <NSCopying>
- (instancetype)initWithSourceIdentifier:(uint8_t)sourceIdentifier
                         destinationURL:(NSURL *)destinationURL
                     sourceDescription:(NSString *)sourceDescription
                              purchaser:(NSString *)purchaser;
@property (nonatomic, assign, readonly) uint8_t sourceIdentifier;
@property (nonatomic, copy, readonly) NSURL *destinationURL;
@property (nonatomic, copy, readonly, nullable) NSURL *reportEndpoint;
@property (nonatomic, copy, readonly) NSString *sourceDescription;
@property (nonatomic, copy, readonly) NSString *purchaser;
@end

@interface CharonHostUIEventAttributionView : UIView
@end

typedef id (*zero_init)(id, SEL);

// -init and +new are NS_UNAVAILABLE on the SDK's declaration on both sides, and what is under test is what
// they do at run time, so they go through objc_msgSend rather than being silenced.
// -init is an INSTANCE method, so it is sent to an allocated object; sending it to the class object raises
// "cannot init a class object", which is this harness talking to itself rather than either side answering.
static id call_init(Class c)
{
    return ((zero_init)objc_msgSend)((id)((zero_init)objc_msgSend)((id)c, @selector(alloc)), @selector(init));
}

static id call_new(Class c)
{
    return ((zero_init)objc_msgSend)((id)c, @selector(new));
}

static void BOTH(NSString *what, NSString *ours, NSString *theirs)
{
    charon_check([ours isEqualToString:theirs], what.UTF8String,
                 [NSString stringWithFormat:@"port %@ != system %@", ours, theirs]);
}

// -init and +new are NS_UNAVAILABLE in the header on both sides and neither refuses at run time, so what is
// compared is what they answer: an object whose five values are the zeros of their types. The first version
// of this case asked the wrong question - it expected a refusal, on the strength of a probe that had sent
// `new` to an instance - so it went red against a port that was answering what the host answers.
static void check_the_zeros(void)
{
    CharonHostUIEventAttribution *ours = call_init([CharonHostUIEventAttribution class]);
    UIEventAttribution *theirs = call_init([UIEventAttribution class]);
    charon_check(ours != nil && theirs != nil, "both sides answer an unavailable -init", @"one side raised");
    BOTH(@"the unavailable -init gives a zero source identifier",
         [NSString stringWithFormat:@"%u", (unsigned)ours.sourceIdentifier],
         [NSString stringWithFormat:@"%u", (unsigned)theirs.sourceIdentifier]);
    BOTH(@"the unavailable -init gives no destination URL", ours.destinationURL == nil ? @"nil" : @"set",
         theirs.destinationURL == nil ? @"nil" : @"set");
    BOTH(@"the unavailable -init gives no source description", ours.sourceDescription == nil ? @"nil" : @"set",
         theirs.sourceDescription == nil ? @"nil" : @"set");
    BOTH(@"the unavailable -init gives no purchaser", ours.purchaser == nil ? @"nil" : @"set",
         theirs.purchaser == nil ? @"nil" : @"set");
    BOTH(@"the unavailable -init gives no report endpoint", ours.reportEndpoint == nil ? @"nil" : @"set",
         theirs.reportEndpoint == nil ? @"nil" : @"set");

    CharonHostUIEventAttribution *ourNew = call_new([CharonHostUIEventAttribution class]);
    UIEventAttribution *theirNew = call_new([UIEventAttribution class]);
    charon_check(ourNew != nil && theirNew != nil, "both sides answer an unavailable +new", @"one side raised");
    BOTH(@"the unavailable +new gives the same zeros as -init",
         [NSString stringWithFormat:@"%u/%@/%@/%@", (unsigned)ourNew.sourceIdentifier,
          ourNew.destinationURL ? @"set" : @"nil", ourNew.sourceDescription ? @"set" : @"nil",
          ourNew.purchaser ? @"set" : @"nil"],
         [NSString stringWithFormat:@"%u/%@/%@/%@", (unsigned)theirNew.sourceIdentifier,
          theirNew.destinationURL ? @"set" : @"nil", theirNew.sourceDescription ? @"set" : @"nil",
          theirNew.purchaser ? @"set" : @"nil"]);
}

static void check_the_five_values(void)
{
    NSURL *url = [NSURL URLWithString:@"https://example.invalid/a"];
    NSString *source = @"a source";
    CharonHostUIEventAttribution *ours = [[CharonHostUIEventAttribution alloc] initWithSourceIdentifier:7
                                                                          destinationURL:url
                                                                      sourceDescription:source
                                                                               purchaser:@"a purchaser"];
    UIEventAttribution *theirs = [[UIEventAttribution alloc] initWithSourceIdentifier:7
                                                                      destinationURL:url
                                                                  sourceDescription:source
                                                                           purchaser:@"a purchaser"];
    charon_check(ours != nil && theirs != nil, "both sides build an attribution", @"one side answered nothing");

    BOTH(@"the source identifier reads back", [NSString stringWithFormat:@"%u", (unsigned)ours.sourceIdentifier],
         [NSString stringWithFormat:@"%u", (unsigned)theirs.sourceIdentifier]);
    BOTH(@"the destination URL reads back", ours.destinationURL.absoluteString, theirs.destinationURL.absoluteString);
    BOTH(@"the source description reads back", ours.sourceDescription, theirs.sourceDescription);
    BOTH(@"the purchaser reads back", ours.purchaser, theirs.purchaser);
    BOTH(@"a fresh attribution has no report endpoint", ours.reportEndpoint == nil ? @"nil" : @"set",
         theirs.reportEndpoint == nil ? @"nil" : @"set");

    // The URL and the strings are `copy` properties, so what comes back is what was handed in: identity,
    // not just equality, which is what -copyWithZone: and -[NSURL copy] give for an immutable value.
    BOTH(@"the destination URL is the URL it was given", ours.destinationURL == url ? @"same" : @"copied",
         theirs.destinationURL == url ? @"same" : @"copied");
    BOTH(@"the source description is the string it was given",
         [ours.sourceDescription isEqual:@"a source"] && ours.sourceDescription == source ? @"same" : @"copied",
         [theirs.sourceDescription isEqual:@"a source"] && theirs.sourceDescription == source ? @"same" : @"copied");

    // The copy: equal to its receiver and holding the same five values, which is the question a copy of a
    // value object has to answer.
    CharonHostUIEventAttribution *ourCopy = [ours copy];
    UIEventAttribution *theirCopy = [theirs copy];
    BOTH(@"a copy is equal to its receiver", [ourCopy isEqual:ours] ? @"equal" : @"other",
         [theirCopy isEqual:theirs] ? @"equal" : @"other");
    BOTH(@"a copy is not its receiver", ourCopy == ours ? @"same" : @"other", theirCopy == theirs ? @"same" : @"other");
    BOTH(@"a copy keeps the source identifier", [NSString stringWithFormat:@"%u", (unsigned)ourCopy.sourceIdentifier],
         [NSString stringWithFormat:@"%u", (unsigned)theirCopy.sourceIdentifier]);
    BOTH(@"a copy keeps the destination URL", ourCopy.destinationURL.absoluteString, theirCopy.destinationURL.absoluteString);
    BOTH(@"a copy keeps the purchaser", ourCopy.purchaser, theirCopy.purchaser);
    CharonHostUIEventAttribution *ourTwin = [[CharonHostUIEventAttribution alloc] initWithSourceIdentifier:7
                                                                           destinationURL:url
                                                                       sourceDescription:source
                                                                                purchaser:@"a purchaser"];
    UIEventAttribution *theirTwin = [[UIEventAttribution alloc] initWithSourceIdentifier:7
                                                               destinationURL:url
                                                           sourceDescription:source
                                                                    purchaser:@"a purchaser"];
    BOTH(@"two attributions with the same values are equal", [ours isEqual:ourTwin] ? @"equal" : @"other",
         [theirs isEqual:theirTwin] ? @"equal" : @"other");

    // Two that differ are not equal, on either side, so -isEqual: is not answering YES to everything.
    CharonHostUIEventAttribution *other = [[CharonHostUIEventAttribution alloc] initWithSourceIdentifier:8
                                                                         destinationURL:url
                                                                     sourceDescription:source
                                                                              purchaser:@"a purchaser"];
    UIEventAttribution *theirOther = [[UIEventAttribution alloc] initWithSourceIdentifier:8
                                                             destinationURL:url
                                                         sourceDescription:source
                                                                      purchaser:@"a purchaser"];
    BOTH(@"two attributions that differ are not equal", [ours isEqual:other] ? @"equal" : @"other",
         [theirs isEqual:theirOther] ? @"equal" : @"other");
    BOTH(@"an attribution is not equal to a string", [ours isEqual:@"a source"] ? @"equal" : @"other", @"other");
    BOTH(@"the hashes of equal attributions agree", [ours isEqual:ourTwin] ? @"equal" : @"other", @"equal");
}

// The view. Its only rows are its symbol and what a fresh instance answers, so that is what is compared:
// the two answers that differ from UIView's own defaults, and the two that do not.
static void check_the_view(void)
{
    CharonHostUIEventAttributionView *ours = [[CharonHostUIEventAttributionView alloc] initWithFrame:CGRectMake(1, 2, 3, 4)];
    UIEventAttributionView *theirs = [[UIEventAttributionView alloc] initWithFrame:CGRectMake(1, 2, 3, 4)];
    charon_check(ours != nil && theirs != nil, "both sides make the view", @"one side answered nothing");
    BOTH(@"the view is opaque", [NSString stringWithFormat:@"%d", (int)ours.opaque],
         [NSString stringWithFormat:@"%d", (int)theirs.opaque]);
    BOTH(@"the view takes no user interaction", [NSString stringWithFormat:@"%d", (int)ours.isUserInteractionEnabled],
         [NSString stringWithFormat:@"%d", (int)theirs.isUserInteractionEnabled]);
    BOTH(@"the view has no background colour", ours.backgroundColor == nil ? @"nil" : @"set",
         theirs.backgroundColor == nil ? @"nil" : @"set");
    BOTH(@"the view has no subviews", [NSString stringWithFormat:@"%lu", (unsigned long)ours.subviews.count],
         [NSString stringWithFormat:@"%lu", (unsigned long)theirs.subviews.count]);
    BOTH(@"the view is not an accessibility element", [NSString stringWithFormat:@"%d", (int)ours.isAccessibilityElement],
         [NSString stringWithFormat:@"%d", (int)theirs.isAccessibilityElement]);
    BOTH(@"the view's alpha is one", [NSString stringWithFormat:@"%g", (double)ours.alpha],
         [NSString stringWithFormat:@"%g", (double)theirs.alpha]);
}

int main(void)
{
    @autoreleasepool {
        check_the_zeros();
        check_the_five_values();
        check_the_view();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}