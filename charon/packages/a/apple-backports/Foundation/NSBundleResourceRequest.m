#import <Foundation/Foundation.h>
#import "CharonMethodProem.h"
#import <objc/runtime.h>

/* NSBundleResourceRequest (iOS 9.0) over the port's release.

   The class is the application's own on-demand resources seen from the bundle that holds them: a set
   of tags, the bundle they resolve in, a priority, and a progress that is complete the moment it
   exists. No release this package is built for has the class, and none has the manifest either, so
   the manifest is read here out of the bundle's own OnDemandResources.plist with -[NSBundle
   pathForResource:ofType:], which every release answers.

   What the host's own class does with it, and where the measurements are: the class is a stub on
   macOS, its public initialiser forwards to a private -initWithTag: and that forwarding is what
   raises, and the two NSBundle additions are inert there. The rules below are the ruling's, and the
   three that the host could be asked about are in facts/Foundation/NSBundleResourceRequest.md:
   -init raises NSInvalidArgumentException with the reason "init is unavailable" (measured);
   the error a tag that is not in the manifest completes with is
   NSBundleOnDemandResourceInvalidTagError, 4994, in NSCocoaErrorDomain (measured out of
   FoundationErrors.h, not out of the host, which cannot complete a request at all); and the two
   NSBundle additions follow the header rather than the host, which answers where the header promises
   a refusal. */

/* The two symbols. Both are API_UNAVAILABLE(macOS), which is why the macOS framework does not emit
   either and why neither value can be measured on this host: they are the header's own words and
   nothing else. The notification is named by its own string, as every NSNotificationName const is;
   the priority is 1.0 because the property's range runs from 0 to 1, with 1 the highest, and
   this one is documented as the maximum amount of resources to make available for finishing this request
   at the earliest possible moment. Facts, not measurements, and the facts file says so. */
double const NSBundleResourceRequestLoadingPriorityUrgent = 1.0;
NSString *const NSBundleResourceRequestLowDiskSpaceNotification = @"NSBundleResourceRequestLowDiskSpaceNotification";

/* The two plist keys. Neither is in any Foundation header on this machine, in the 16.4 SDK or the
   26.2 one: they are the documented asset-pack format, and the manifest the ruling describes has
   exactly this shape. */
static NSString *const charon_manifest_resource = @"OnDemandResources";
static NSString *const charon_manifest_tags_key = @"NSBundleResourceRequestTags";
static NSString *const charon_manifest_pack_path_key = @"NSBundleResourceRequestPath";

/* The error a tag that the bundle's manifest does not name completes with: 4994 out of
   FoundationErrors.h, the host's own header text says that the application specified a tag the system
   cannot locate in its tag manifest. */
static NSInteger const charon_invalid_tag = 4994;

static NSString *CharonInvalidTagError(NSString *tag)
{
    return [NSString stringWithFormat:NSLocalizedString(@"The value “%@” is not a tag in this bundle's asset manifest.",
                                                       @"NSBundleResourceRequest invalid tag"), tag];
}

/* The manifest, read once per bundle and held beside the class rather than in a category: a category
   cannot add storage on armv7, and this file exports the class, so the table is here for the same
   reason every other backport keeps its state in its own object. */
static NSMutableDictionary *CharonPriorities(void)
{
    static NSMutableDictionary *priorities;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        priorities = [NSMutableDictionary dictionary];
    });
    return priorities;
}

/* The tag map of a bundle: tag -> the asset packs it names. nil when the bundle carries no manifest,
   which is every release's ordinary case and every application that does not use on-demand
   resources. */
static NSMutableDictionary *CharonManifests(void)
{
    static NSMutableDictionary *manifests;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manifests = [NSMutableDictionary dictionary];
    });
    return manifests;
}

/* The tag map of a bundle: tag -> the asset packs it names. nil when the bundle carries no manifest,
   which is every release's ordinary case and every application that does not use on-demand
   resources. */
static NSDictionary *CharonManifestForBundle(NSBundle *bundle)
{
    if (bundle == nil)
        return nil;
    NSString *key = bundle.bundlePath ?: @"";
    NSDictionary *held = CharonManifests()[key];
    if (held)
        return held;
    NSDictionary *manifest = nil;
    NSString *path = [bundle pathForResource:charon_manifest_resource ofType:@"plist"];
    if (path)
        manifest = [NSDictionary dictionaryWithContentsOfFile:path];
    NSDictionary *tags = manifest[charon_manifest_tags_key];
    CharonManifests()[key] = [tags isKindOfClass:[NSDictionary class]] ? [tags mutableCopy] : [NSMutableDictionary dictionary];
    return CharonManifests()[key];
}

/* A tag is resolvable when the bundle's manifest names it. The packs it maps to are inside the
   bundle, so nothing is ever downloaded: this is the documented behaviour when the packs are already
   there, and the ruling the band was given is to implement exactly that. */
static BOOL CharonTagIsResolvable(NSBundle *bundle, NSString *tag)
{
    return CharonManifestForBundle(bundle)[tag] != nil;
}

@implementation NSBundleResourceRequest {
    NSSet<NSString *> *_tags;
    NSBundle *_bundle;
    double _loadingPriority;
    NSProgress *_progress;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)init
{
    /* The header marks -init unavailable on every platform and the host answers by refusing, with this
       reason. An intent needs tags, so there is nothing for it to be. */
    [NSException raise:NSInvalidArgumentException format:@"init is unavailable"];
    return nil;
}

- (instancetype)initWithTags:(NSSet<NSString *> *)tags
{
    return [self initWithTags:tags bundle:(NSBundle * _Nonnull)nil];
}

- (instancetype)initWithTags:(NSSet<NSString *> *)tags bundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _tags = [tags copy];
        /* The header's default: with no bundle given, the main bundle is used. */
        _bundle = bundle ?: [NSBundle mainBundle];
        /* "The default priority is 0.5" */
        _loadingPriority = 0.5;
        /* The host's shape exactly, measured: a fresh NSProgress with no units set is indeterminate
           and finished, and -fractionCompleted reads 1 - the counts are left alone rather than set,
           because setting them is what took the port off 1. */
        _progress = [[NSProgress alloc] init];
    }
    return self;
}

- (NSSet<NSString *> *)tags
{
    return _tags;
}

- (NSBundle *)bundle
{
    return _bundle;
}

- (double)loadingPriority
{
    return _loadingPriority;
}

- (void)setLoadingPriority:(double)loadingPriority
{
    _loadingPriority = loadingPriority;
}

- (NSProgress *)progress
{
    return _progress;
}

/* The tags the manifest does not name. A request for a tag the bundle has is a request the bundle can
   satisfy, so an empty answer is the whole of the "can you do this" question. */
- (NSSet<NSString *> *)charon_unresolvableTags
{
    NSMutableSet *missing = [NSMutableSet set];
    for (NSString *tag in _tags)
        if (!CharonTagIsResolvable(_bundle, tag))
            [missing addObject:tag];
    return missing;
}

- (NSError *)charon_errorForUnresolvableTags:(NSSet<NSString *> *)missing
{
    if ([missing count] == 0)
        return nil;
    NSString *tag = [[missing allObjects] sortedArrayUsingSelector:@selector(compare:)][0];
    return [NSError errorWithDomain:NSCocoaErrorDomain
                               code:charon_invalid_tag
                           userInfo:@{NSLocalizedDescriptionKey: CharonInvalidTagError(tag)}];
}

- (void)beginAccessingResourcesWithCompletionHandler:(void (^)(NSError *error))handler
{
    /* Everything resolvable is already there, so the handler runs once with nothing, or once with the
       tag the manifest does not name. There is no download to wait for and no queue to hop to. */
    if (handler)
        handler([self charon_errorForUnresolvableTags:[self charon_unresolvableTags]]);
}

- (void)conditionallyBeginAccessingResourcesWithCompletionHandler:(void (^)(BOOL available))handler
{
    /* Yes whatever the tags are: the packs are in the bundle, so there is nothing to wait for, and
       the host answers YES for a tag its manifest does not name as well. */
    if (handler)
        handler(YES);
}

- (void)endAccessingResources
{
    /* Nothing was taken: the packs never left the bundle. The header says the completion may only run after a
       callback from -begin has been received, which is a caller's discipline and the port does not enforce
       it, because nothing is held and a call out of order cannot leak. */
}

@end

/* The SDK declares this category itself, behind API_UNAVAILABLE(macOS), so redeclaring it would be a
   duplicate; only the implementation is added here, against the SDK's own declaration. */
/* The two additions, on NSBundle, in the header's own terms. macOS ships them as stubs that answer
   and read back 0 where the header promises an exception, so the host cannot hold the port to them and
   the port follows the header.

   They are *installed*, not compiled in, and only when NSBundle does not already answer: a compiled
   category attaches unconditionally and would override the host's own two methods on macOS, which is
   what broke the host's private -initWithTag: the first time this ran beside it. The fleet rule is
   that the port installs nothing where the host already has the API, and an answer to
   -instancesRespondToSelector: is how that is asked of it - the same shape as
   Foundation/NSBundle+ReceiptURL.m's +load, which replaces or adds per selector.

   The two are plain C functions rather than methods, because they are the implementations a runtime
   install needs and because a method's self would be a request rather than the bundle the caller
   asked about. They are used only here and live in the same object as the class, so no band's file
   can be left out from under them. */
@implementation NSBundle (NSBundleResourceRequestAdditions)

- (void)setPreservationPriority:(double)priority forTags:(NSSet<NSString *> *)tags
{
    NSBundle *bundle = self;
    SEL selector = _cmd;
    NSDictionary *manifest = CharonManifestForBundle(bundle);
    if ([manifest count] == 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@: this bundle has no on demand resource tag information",
                           charon_method_proem(bundle, selector)];
        return;
    }
    NSMutableDictionary *priorities = CharonPriorities()[bundle.bundlePath ?: @""];
    for (NSString *tag in tags) {
        if (manifest[tag] == nil) {
            [NSException raise:NSInvalidArgumentException
                        format:@"%@: \u201c%@\u201d is not a tag in this bundle's asset manifest",
                               charon_method_proem(bundle, selector), tag];
            return;
        }
        priorities[tag] = @(priority);
    }
}

- (double)preservationPriorityForTag:(NSString *)tag
{
    NSNumber *held = CharonPriorities()[self.bundlePath ?: @""][tag];
    return held ? [held doubleValue] : 0.0;
}

@end

/* A constructor, not +load: +load of a backport runs before the runtime has vended the framework's
   classes, and asking one then traps (charon/AGENTS.md, Traps: "+load in a backport", and
   Foundation/NSBundle+ReceiptURL.m, whose categories are attached from attach.c's constructor for the
   same reason). */
/* The install, taking the class it is to install on, so that a caller can hand it one that has
   neither method. The constructor below passes NSBundle; the differential passes a class of its own,
   which is the only way the *decision* can be tested at all, because on a host that already has both
   the two queries agree and nothing is said about whether the port would have installed them. */
void CharonInstallNSBundleAdditions(Class bundle)
{
    /* class_getInstanceMethod, not -instancesRespondToSelector:. The optimized stub behind
       -instancesRespondToSelector: traps with brk #0xc472 for a selector that nothing has
       registered (measured by the band that hit the same trap, 99038dbf), and on a class of this
       file's own making neither selector is registered anywhere. Both answers are read before either
       mutation: adding a method rewrites the class, and a pointer held across that is stale. */
    BOOL hasSet = class_getInstanceMethod(bundle, @selector(setPreservationPriority:forTags:)) != NULL;
    BOOL hasGet = class_getInstanceMethod(bundle, @selector(preservationPriorityForTag:)) != NULL;
    if (!hasSet)
        class_addMethod(bundle, @selector(setPreservationPriority:forTags:),
                        class_getMethodImplementation([NSBundle class], @selector(setPreservationPriority:forTags:)),
                        "v@:@d@");
    if (!hasGet)
        class_addMethod(bundle, @selector(preservationPriorityForTag:),
                        class_getMethodImplementation([NSBundle class], @selector(preservationPriorityForTag:)),
                        "d@:@@");
}

__attribute__((constructor)) static void CharonInstallOnNSBundle(void)
{
    Class bundle = objc_getClass("NSBundle");
    if (bundle == Nil) {
        fprintf(stderr, "charon: no NSBundle in this process; the two additions are not installed\n");
        return;
    }
    CharonInstallNSBundleAdditions(bundle);
}
