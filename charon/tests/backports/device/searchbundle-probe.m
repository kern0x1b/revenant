// Standalone diagnostic: writes one synthetic CSSearchableItem into the shared store, then drives
// a real SPSearchAgent query against it, exactly the code path SpringBoard's own search uses -
// -_loadSearchBundles, our datastore, -performQuery:withResultsPipe:, back to this delegate.
// printf+fflush only: NSLog's ASL channel from a process launched outside the normal app/daemon
// launch path was already found silent once this session, so nothing here depends on it working -
// this run also answers, as a side effect, whether NSLog reaches this process at all, printed as
// its own line rather than assumed.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString *const CharonSpotlightSharedRoot = @"/var/mobile/Library/Caches/org.charon.corespotlight";
static NSString *const kProbeBundleID = @"org.charon.corespotlight.probe";
static NSString *const kProbeMarker = @"CharonProbeXyzzyPlugh19640523";

static void writeSyntheticItem(void)
{
    void *csHandle = dlopen("/usr/lib/charon/org.charon.apple-backports/libCoreSpotlightBackports.dylib", RTLD_LAZY);
    printf("probe: dlopen libCoreSpotlightBackports.dylib -> %p\n", csHandle);
    fflush(stdout);
    Class attrClass = NSClassFromString(@"CSSearchableItemAttributeSet");
    Class itemClass = NSClassFromString(@"CSSearchableItem");
    printf("probe: CSSearchableItemAttributeSet=%p CSSearchableItem=%p\n", attrClass, itemClass);
    fflush(stdout);
    if (!attrClass || !itemClass)
        return;

    id attrs = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)((id)attrClass, sel_registerName("alloc")), sel_registerName("init"));
    [attrs setValue:kProbeMarker forKey:@"title"];

    id item = ((id (*)(id, SEL, id, id, id))objc_msgSend)(
        ((id (*)(id, SEL))objc_msgSend)((id)itemClass, sel_registerName("alloc")), sel_registerName("initWithUniqueIdentifier:domainIdentifier:attributeSet:"),
        @"org.charon.corespotlight.probe.item1", @"org.charon.corespotlight.probe", attrs);
    printf("probe: built synthetic item -> %p\n", item);
    fflush(stdout);
    if (!item)
        return;

    NSString *directory = [CharonSpotlightSharedRoot stringByAppendingPathComponent:kProbeBundleID];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES
                                                attributes:@{NSFilePosixPermissions: @(0777)} error:NULL];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:item];
    NSDictionary *disk = @{@"entries": @{@"org.charon.corespotlight.probe.item1": archived}};
    NSString *path = [directory stringByAppendingPathComponent:@"probe.plist"];
    BOOL wrote = [disk writeToFile:path atomically:YES];
    printf("probe: wrote %s -> %d\n", path.UTF8String, wrote);
    fflush(stdout);
}

@interface CharonProbeDelegate : NSObject
@property (nonatomic, strong) NSMutableArray *seenResults;
@property (nonatomic) BOOL completed;
@end

@implementation CharonProbeDelegate
- (instancetype)init { if ((self = [super init])) { _seenResults = [NSMutableArray array]; } return self; }

- (void)searchDaemonQuery:(id)query addedResults:(id)results
{
    printf("probe: NSLog channel check below this line, from -searchDaemonQuery:addedResults:\n");
    fflush(stdout);
    NSLog(@"probe: NSLog reached ASL from -searchDaemonQuery:addedResults:");
    printf("probe: addedResults count=%lu\n", (unsigned long)[results count]);
    fflush(stdout);
    [self.seenResults addObjectsFromArray:results];
}

- (void)searchDaemonQuery:(id)query encounteredError:(id)error
{
    printf("probe: searchDaemonQuery:encounteredError: %s\n", [[error description] UTF8String]);
    fflush(stdout);
}

- (void)searchDaemonQueryCompleted:(id)query
{
    printf("probe: searchDaemonQueryCompleted:\n");
    fflush(stdout);
    self.completed = YES;
}
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        printf("probe: printf/fflush channel - if you are reading this over ssh, this channel works for this process\n");
        fflush(stdout);

        writeSyntheticItem();

        void *handle = dlopen("/System/Library/PrivateFrameworks/Search.framework/Search", RTLD_LAZY);
        printf("probe: dlopen Search.framework -> %p\n", handle);
        fflush(stdout);
        if (!handle)
            return 1;

        Class agentClass = NSClassFromString(@"SPSearchAgent");
        printf("probe: SPSearchAgent class -> %p\n", agentClass);
        fflush(stdout);
        if (!agentClass)
            return 1;

        id agent = ((id (*)(id, SEL, int, id))objc_msgSend)(
            ((id (*)(id, SEL))objc_msgSend)((id)agentClass, sel_registerName("alloc")), sel_registerName("initWithOptions:andSearchDomains:"), 0, nil);
        printf("probe: agent.searchDomains after init = %s\n", [[((id (*)(id, SEL))objc_msgSend)(agent, sel_registerName("searchDomains")) description] UTF8String]);
        fflush(stdout);
        printf("probe: SPSearchAgent instance -> %p\n", agent);
        fflush(stdout);
        if (!agent)
            return 1;

        CharonProbeDelegate *delegate = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)((id)[CharonProbeDelegate class], sel_registerName("alloc")), sel_registerName("init"));
        NSArray *domains = ((id (*)(id, SEL))objc_msgSend)(agent, sel_registerName("searchDomains"));
        NSArray *withOurs = [domains arrayByAddingObject:@999];
        ((void (*)(id, SEL, id))objc_msgSend)(agent, sel_registerName("setSearchDomains:"), withOurs);
        printf("probe: forced searchDomains -> %s\n", [[((id (*)(id, SEL))objc_msgSend)(agent, sel_registerName("searchDomains")) description] UTF8String]);
        fflush(stdout);
        Protocol *daemonProtocol = objc_getProtocol("SPDaemonQueryDelegate");
        printf("probe: objc_getProtocol(SPDaemonQueryDelegate) -> %p\n", daemonProtocol);
        fflush(stdout);
        if (daemonProtocol) {
            BOOL added = class_addProtocol([CharonProbeDelegate class], daemonProtocol);
            printf("probe: class_addProtocol -> %d, now conforms=%d\n", added, [delegate conformsToProtocol:daemonProtocol]);
            fflush(stdout);
        }
        ((void (*)(id, SEL, id))objc_msgSend)(agent, sel_registerName("setDelegate:"), delegate);

        NSString *query = argc > 1 ? @(argv[1]) : kProbeMarker;
        printf("probe: setQueryString: \"%s\"\n", query.UTF8String);
        fflush(stdout);
        BOOL accepted = ((BOOL (*)(id, SEL, id))objc_msgSend)(agent, sel_registerName("setQueryString:"), query);
        printf("probe: setQueryString: accepted=%d\n", accepted);
        fflush(stdout);

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:15];
        BOOL queryComplete = NO;
        int resultCount = 0;
        while (!queryComplete && [deadline timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            queryComplete = ((BOOL (*)(id, SEL))objc_msgSend)(agent, sel_registerName("queryComplete"));
            resultCount = ((int (*)(id, SEL))objc_msgSend)(agent, sel_registerName("resultCount"));
            printf("probe: polling queryComplete=%d resultCount=%d delegateResults=%lu\n",
                   queryComplete, resultCount, (unsigned long)delegate.seenResults.count);
            fflush(stdout);
        }
        // The delegate callbacks never fired even once (checked separately below); resultCount and
        // -sectionAtIndex: are read directly off the agent instead, since those answered real
        // numbers above while the delegate stayed silent - two different channels, only one proven.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        unsigned int sectionCount = ((unsigned int (*)(id, SEL))objc_msgSend)(agent, sel_registerName("sectionCount"));
        printf("probe: sectionCount=%u\n", sectionCount);
        fflush(stdout);
        BOOL foundOurs = NO;
        for (unsigned int i = 0; i < sectionCount; i++) {
            id section = ((id (*)(id, SEL, unsigned int))objc_msgSend)(agent, sel_registerName("sectionAtIndex:"), i);
            NSString *category = [section valueForKey:@"category"];
            NSString *displayIdentifier = [section valueForKey:@"displayIdentifier"];
            NSArray *results = [section valueForKey:@"results"];
            printf("probe: section[%u] category=\"%s\" displayIdentifier=\"%s\" results=%lu\n",
                   i, category.UTF8String ?: "(nil)", displayIdentifier.UTF8String ?: "(nil)", (unsigned long)results.count);
            fflush(stdout);
            for (id result in results) {
                NSString *title = [result valueForKey:@"title"];
                BOOL isOurs = [title isEqualToString:kProbeMarker];
                if (isOurs) {
                    foundOurs = YES;
                    printf("probe: MATCH in section \"%s\" - our synthetic result came back: title=\"%s\"\n", category.UTF8String ?: "(nil)", title.UTF8String);
                } else {
                    printf("probe: a foreign result in section \"%s\" - omitted from this log (privacy)\n", category.UTF8String ?: "(nil)");
                }
                fflush(stdout);
            }
        }
        printf("probe: FINAL VERDICT foundOurs=%d delegateFired=%d (delegateResults=%lu)\n",
               foundOurs, delegate.seenResults.count > 0 || delegate.completed, (unsigned long)delegate.seenResults.count);
        fflush(stdout);

        ((void (*)(id, SEL))objc_msgSend)(agent, sel_registerName("invalidate"));
        return 0;
    }
}
