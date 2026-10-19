// CKShareRequestAccessOperation, the one operation iOS 26 added.
//
// Asking to be let into a share is the other half of accepting one: the inviter says who may ask and
// the asker asks, and the service's answer is per share URL. The class is in a file of its own
// because the band machinery puts an object in the band of the release its API arrived in, and this
// arrived in 26 - the first thing in this package past the releases the fleet's own libraries cover.
//
// The interface is the iOS 26.2 header's own, transcribed into CharonCKIOS26.h because the 16.4
// headers this package builds against do not declare it. The three siblings of that surface,
// CKShareAccessRequester, CKShareBlockedIdentity and the members of CKShare that say a share may ask
// at all, are named at the bottom of that header and are not here: they are values the service fills
// in, and the CKShare members cannot be answered without CKShare itself.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"
#import "CharonCKIOS26.h"

@implementation CKShareRequestAccessOperation

// The three properties are declared in CharonCKIOS26.h and implemented here, so the build's
// missing-synthesis check asks for each of them by name.
@synthesize shareURLs = _shareURLs;
@synthesize perShareAccessRequestCompletionBlock = _perShareAccessRequestCompletionBlock;
@synthesize shareRequestAccessCompletionBlock = _shareRequestAccessCompletionBlock;

// -init is the header's designated initializer: [super init] is CKOperation's own, which does the set-up
// for anything below the abstract base and refuses only the base itself -- what the host answers for the
// base class and for each concrete subclass is measured, with both spellings, by
// tests/backports/host/cloudkit/initializers-host.m. The one default this class adds is an empty list.
- (instancetype)init
{
    self = [super init];
    if (self) {
        _shareURLs = @[];
    }
    return self;
}

- (instancetype)initWithShareURLs:(NSArray<NSURL *> *)shareURLs
{
    self = [self init];
    if (self) {
        _shareURLs = [shareURLs copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.shareURLs.count) {
        // No URL is a request the service has nothing to answer, and the code the header names for a
        // malformed request is the one that fits.
        if (self.shareRequestAccessCompletionBlock) {
            self.shareRequestAccessCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"No share URL", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableArray *urls = [NSMutableArray array];
    for (NSURL *url in self.shareURLs) {
        [urls addObject:url.absoluteString];
    }
    __unsafe_unretained CKShareRequestAccessOperation *weakSelf = self;
    // The request is the service's own, under the shares root, and the answer is one document per
    // URL. A share whose owner does not allow access requests refuses here rather than pretending the
    // ask was made, and the refusal is whatever the service answered for that item - handed over as
    // that item's own error, the way every other operation in this family hands over a refusal.
    [self runMethod:@"POST" path:@"shares/requestAccess" body:@{@"shareURLs": urls}
       completion:^(id answer, NSError *error) {
        CKShareRequestAccessOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.shareRequestAccessCompletionBlock) {
                strongSelf.shareRequestAccessCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"shares"]) {
            NSString *url = document[@"shareURL"];
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            if (itemError) {
                failures[url ?: @"?"] = itemError;
            }
            if (strongSelf.perShareAccessRequestCompletionBlock) {
                strongSelf.perShareAccessRequestCompletionBlock(url ? [NSURL URLWithString:url] : nil,
                                                                 itemError);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.shareRequestAccessCompletionBlock) {
            strongSelf.shareRequestAccessCompletionBlock(overall);
        }
    }];
}

@end