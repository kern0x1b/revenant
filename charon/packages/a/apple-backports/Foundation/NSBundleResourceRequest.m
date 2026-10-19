#import <Foundation/Foundation.h>
#import "CharonMethodProem.h"
#import <objc/runtime.h>

double const NSBundleResourceRequestLoadingPriorityUrgent = 1.0;
NSString *const NSBundleResourceRequestLowDiskSpaceNotification = @"NSBundleResourceRequestLowDiskSpaceNotification";

static NSString *const charon_manifest_resource = @"OnDemandResources";
static NSString *const charon_manifest_tags_key = @"NSBundleResourceRequestTags";
static NSString *const charon_manifest_pack_path_key = @"NSBundleResourceRequestPath";

static NSInteger const charon_invalid_tag = 4994;

static NSString *CharonInvalidTagError(NSString *tag)
{
    return [NSString stringWithFormat:NSLocalizedString(@"The value “%@” is not a tag in this bundle's asset manifest.",
                                                       @"NSBundleResourceRequest invalid tag"), tag];
}

static NSMutableDictionary *CharonPriorities(void)
{
    static NSMutableDictionary *priorities;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        priorities = [NSMutableDictionary dictionary];
    });
    return priorities;
}

static NSMutableDictionary *CharonManifests(void)
{
    static NSMutableDictionary *manifests;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manifests = [NSMutableDictionary dictionary];
    });
    return manifests;
}

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
        _bundle = bundle ?: [NSBundle mainBundle];
        _loadingPriority = 0.5;
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
    if (handler)
        handler([self charon_errorForUnresolvableTags:[self charon_unresolvableTags]]);
}

- (void)conditionallyBeginAccessingResourcesWithCompletionHandler:(void (^)(BOOL available))handler
{
    if (handler)
        handler(YES);
}

- (void)endAccessingResources
{
}

@end

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

void CharonInstallNSBundleAdditions(Class bundle)
{
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
