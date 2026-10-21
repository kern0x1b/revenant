#import <UIKit/UIKit.h>

static NSMapTable *RevenantRestorationObjects;
static NSHashTable *RevenantRestoredObjects;
static NSMutableDictionary *RevenantPendingState;
static BOOL RevenantRestorationLoaded;
static BOOL RevenantRestorationObserving;
static BOOL RevenantRestorationFinishScheduled;

static NSString *revenant_restoration_file(void)
{
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *identifier = [NSBundle mainBundle].bundleIdentifier ?: @"app";
    return [[[library stringByAppendingPathComponent:@"Saved Application State"] stringByAppendingPathComponent:identifier]
        stringByAppendingPathExtension:@"registeredState"];
}

static NSString *revenant_restoration_path(id object, NSString *identifier)
{
    NSMutableArray *path = [NSMutableArray arrayWithObject:identifier];
    id parent = [object respondsToSelector:@selector(restorationParent)] ? [object restorationParent] : nil;
    for (NSUInteger depth = 0; parent && depth < 64; depth++) {
        NSString *parentIdentifier = [parent respondsToSelector:@selector(restorationIdentifier)] ? [parent restorationIdentifier] : nil;
        if (parentIdentifier.length)
            [path insertObject:parentIdentifier atIndex:0];
        parent = [parent respondsToSelector:@selector(restorationParent)] ? [parent restorationParent] : nil;
    }
    return [path componentsJoinedByString:@"/"];
}

static void revenant_encode_application_header(NSKeyedArchiver *coder)
{
    [coder encodeObject:[NSBundle mainBundle].infoDictionary[(__bridge NSString *)kCFBundleVersionKey] forKey:UIApplicationStateRestorationBundleVersionKey];
    [coder encodeObject:@([UIDevice currentDevice].userInterfaceIdiom) forKey:UIApplicationStateRestorationUserInterfaceIdiomKey];
}

static void revenant_save_registered(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    id<UIApplicationDelegate> delegate = application.delegate;
    if (!RevenantRestorationObjects.count || ![delegate respondsToSelector:@selector(application:shouldSaveApplicationState:)])
        return;
    NSMutableData *header = [NSMutableData data];
    NSKeyedArchiver *applicationCoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:header];
    revenant_encode_application_header(applicationCoder);
    BOOL allowed = [delegate application:application shouldSaveApplicationState:applicationCoder];
    [applicationCoder finishEncoding];
    if (!allowed)
        return;
    NSMutableDictionary *states = [NSMutableDictionary dictionary];
    for (NSString *key in RevenantRestorationObjects.keyEnumerator.allObjects) {
        id object = [RevenantRestorationObjects objectForKey:key];
        if (![object respondsToSelector:@selector(encodeRestorableStateWithCoder:)])
            continue;
        NSMutableData *state = [NSMutableData data];
        NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:state];
        [object encodeRestorableStateWithCoder:coder];
        [coder finishEncoding];
        states[key] = state;
    }
    NSString *file = revenant_restoration_file();
    [[NSFileManager defaultManager] createDirectoryAtPath:[file stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    [NSKeyedArchiver archiveRootObject:@{@"header": header, @"objects": states} toFile:file];
}

static void revenant_load_registered(void)
{
    if (RevenantRestorationLoaded)
        return;
    RevenantRestorationLoaded = YES;
    NSData *data = [NSData dataWithContentsOfFile:revenant_restoration_file()];
    if (!data)
        return;
    NSDictionary *root = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (![root isKindOfClass:[NSDictionary class]] || ![root[@"header"] isKindOfClass:[NSData class]] || ![root[@"objects"] isKindOfClass:[NSDictionary class]])
        return;
    UIApplication *application = [UIApplication sharedApplication];
    id<UIApplicationDelegate> delegate = application.delegate;
    if (![delegate respondsToSelector:@selector(application:shouldRestoreApplicationState:)])
        return;
    NSKeyedUnarchiver *applicationCoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:root[@"header"]];
    BOOL allowed = [delegate application:application shouldRestoreApplicationState:applicationCoder];
    [applicationCoder finishDecoding];
    if (allowed)
        RevenantPendingState = [root[@"objects"] mutableCopy];
}

static void revenant_finish_restoring(void)
{
    if (RevenantRestorationFinishScheduled)
        return;
    RevenantRestorationFinishScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        RevenantRestorationFinishScheduled = NO;
        for (id object in RevenantRestoredObjects.allObjects) {
            if ([object respondsToSelector:@selector(applicationFinishedRestoringState)])
                [object applicationFinishedRestoringState];
        }
        [RevenantRestoredObjects removeAllObjects];
    });
}

static void revenant_observe_application(void)
{
    if (RevenantRestorationObserving)
        return;
    RevenantRestorationObserving = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    void (^save)(NSNotification *) = ^(NSNotification *note) {
        revenant_save_registered();
    };
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:save];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:save];
}

@implementation UIApplication (RevenantStateRestoration7)

+ (void)registerObjectForStateRestoration:(id<UIStateRestoring>)object restorationIdentifier:(NSString *)restorationIdentifier
{
    if (!object || !restorationIdentifier.length)
        [NSException raise:NSInvalidArgumentException format:@"+[UIApplication registerObjectForStateRestoration:restorationIdentifier:] needs an object and a non-empty restoration identifier"];
    if (!RevenantRestorationObjects) {
        RevenantRestorationObjects = [NSMapTable strongToWeakObjectsMapTable];
        RevenantRestoredObjects = [NSHashTable weakObjectsHashTable];
    }
    revenant_observe_application();
    NSString *key = revenant_restoration_path(object, restorationIdentifier);
    [RevenantRestorationObjects setObject:object forKey:key];
    revenant_load_registered();
    NSData *state = RevenantPendingState[key];
    if (!state)
        return;
    [RevenantPendingState removeObjectForKey:key];
    if (!RevenantPendingState.count)
        RevenantPendingState = nil;
    if ([object respondsToSelector:@selector(decodeRestorableStateWithCoder:)]) {
        NSKeyedUnarchiver *coder = [[NSKeyedUnarchiver alloc] initForReadingWithData:state];
        [object decodeRestorableStateWithCoder:coder];
        [coder finishDecoding];
    }
    [RevenantRestoredObjects addObject:object];
    revenant_finish_restoring();
}

@end
