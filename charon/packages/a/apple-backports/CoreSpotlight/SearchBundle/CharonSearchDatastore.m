// The principal class of org.charon.corespotlight.searchBundle, packaged separately from
// libCoreSpotlightBackports.dylib (see write_searchbundle in modules/apple/backports.lua) and
// installed at /System/Library/SearchBundles/, the directory this session measured
// Search.framework's own -_loadSearchBundles to scan
// (.agent-work/handoffs/2026-09-23-corespotlight-searchbundle-measurement.md).
//
// The protocol here is not guessed: NotesDatastore, MobileNotes.searchBundle's own principal
// class, was read with llvm-otool -oV (the tool that bypasses the extract()/otool defect this
// session also closed practically) and its selectors resolved against the iOS 6.1.3 shared cache
// directly, cross-checked against SPSearchDatastore's own required-method list rather than trusted
// from a nearby string. A CharonSearchDatastore instance is created by name, at runtime, as a real
// subclass of the release's own SPSearchDatastore (objc_allocateClassPair, the same technique this
// project already uses to extend private base classes it cannot import a header for), the way
// NotesDatastore itself is a real subclass rather than a bare NSObject that happens to answer the
// protocol's selectors.
// CSSearchableItem/CSSearchableItemAttributeSet are this port's own classes (CoreSpotlight.framework
// does not exist on iOS 6), resolved by name at runtime through the dlopen below - no
// <CoreSpotlight/CoreSpotlight.h> import here, and every value that crosses that boundary is typed
// id and read with valueForKey:, the way this project already handles a symbol a real SDK header
// would otherwise bind at link time for a class this specific binary must not require.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "../CharonSpotlightStore.h"

// write_searchbundle passes the package's install folder (INSTALL_FOLDER in modules/apple/backports.lua).
#ifndef CHARON_BACKPORTS_INSTALL_FOLDER
#error "CHARON_BACKPORTS_INSTALL_FOLDER must be defined by write_searchbundle"
#endif

// CSSearchableItem is this port's own class, not Apple's - iOS 6 carries no CoreSpotlight.framework
// at all - so unarchiving one needs the class registered first, which only happens once the band's
// own dylib is loaded. The install path a device's own postinst keeps linked regardless of which
// band answers this release, so this dlopen reaches the right implementation without the bundle
// needing to be rebuilt or relinked per band.
static void CharonSearchLoadClasses(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *library = [@CHARON_BACKPORTS_INSTALL_FOLDER stringByAppendingPathComponent:@"libCoreSpotlightBackports.dylib"];
        if (!dlopen(library.fileSystemRepresentation, RTLD_LAZY))
            NSLog(@"CharonSearchDatastore: cannot load %@: %s", library, dlerror());
    });
}

static NSArray *CharonSearchLoadAllItems(void)
{
    CharonSearchLoadClasses();
    Class itemClass = NSClassFromString(@"CSSearchableItem");
    if (!itemClass) {
        NSLog(@"CharonSearchDatastore: CSSearchableItem is not registered; no indexed item can be read");
        return [NSArray array];
    }
    NSMutableArray *items = [NSMutableArray array];
    NSFileManager *files = [NSFileManager defaultManager];
    for (NSString *application in [files contentsOfDirectoryAtPath:CHARON_SPOTLIGHT_SHARED_ROOT error:NULL]) {
        NSString *appDirectory = [CHARON_SPOTLIGHT_SHARED_ROOT stringByAppendingPathComponent:application];
        for (NSString *name in [files contentsOfDirectoryAtPath:appDirectory error:NULL]) {
            if (![name.pathExtension isEqualToString:@"plist"])
                continue;
            NSString *file = [appDirectory stringByAppendingPathComponent:name];
            // Any application can write this directory, so nothing read from it is trusted to have the
            // shape CSSearchableIndex.m writes: a file that is not a dictionary of "entries", an entry
            // that is not archive data, an archive that raises, and an archive that decodes to nothing
            // (garbage, or no "root" object) are each logged as rejected rather than dropped silently.
            NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:file];
            id entries = disk[@"entries"];
            if (![entries isKindOfClass:[NSDictionary class]]) {
                NSLog(@"CharonSearchDatastore: rejected %@: %@", file, disk ? [NSString stringWithFormat:@"its entries are %@, not a dictionary", entries ? [NSString stringWithFormat:@"a %@", [entries class]] : @"missing"] : @"not a property list dictionary");
                continue;
            }
            for (id key in entries) {
                id archived = entries[key];
                if (![archived isKindOfClass:[NSData class]]) {
                    NSLog(@"CharonSearchDatastore: rejected entry %@ of %@: a %@, not archive data", key, file, [archived class]);
                    continue;
                }
                // The store is written by every indexing application, so it is decoded the secure way
                // (NSSecureCoding and -requiresSecureCoding are iOS 6.0): only a CSSearchableItem and
                // the classes its own -initWithCoder: names are instantiated inside searchd. "root" is
                // the key +[NSKeyedArchiver archivedDataWithRootObject:] writes the object under;
                // NSKeyedArchiveRootObjectKey, its exported name, is iOS 7.0.
                id item = nil;
                @try {
                    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archived];
                    unarchiver.requiresSecureCoding = YES;
                    item = [unarchiver decodeObjectOfClass:itemClass forKey:@"root"];
                    [unarchiver finishDecoding];
                } @catch (NSException *exception) {
                    NSLog(@"CharonSearchDatastore: rejected entry %@ of %@: %@: %@", key, file, exception.name, exception.reason);
                    continue;
                }
                if (![item isKindOfClass:itemClass]) {
                    NSLog(@"CharonSearchDatastore: rejected entry %@ of %@: it decodes to no %@ (%@)", key, file, itemClass, item ? NSStringFromClass([item class]) : @"nothing");
                    continue;
                }
                [items addObject:item];
            }
        }
    }
    return items;
}

static NSArray *CharonSearchMatches(id query)
{
    // -searchString is a readonly property of the query searchd hands in (read with llvm-otool,
    // facts/CoreSpotlight/CoreSpotlight.md); a query without it is a release this bundle does not
    // know, said so rather than read as "nothing matched".
    SEL getter = sel_registerName("searchString");
    if (![query respondsToSelector:getter]) {
        NSLog(@"CharonSearchDatastore: the query, a %@, has no -searchString; this datastore cannot answer it", [query class]);
        return [NSArray array];
    }
    NSString *searchString = ((id (*)(id, SEL))objc_msgSend)(query, getter);
    if (searchString.length == 0)
        return [NSArray array];
    NSArray *items = CharonSearchLoadAllItems();
    NSMutableArray *results = [NSMutableArray array];
    // Measured on device: this factory is a class method of SPContentResult (our own base class,
    // confirmed by apple.objc's inventory() reading the real __objc_classlist entry, not strings),
    // not SPSearchResult as an earlier strings-only pass attributed it - SPSearchResult only
    // happens to be SPContentResult's own superclass, a second wrong-owner mistake this pass
    // corrected on measurement rather than compounding on top of the first.
    Class resultClass = NSClassFromString(@"SPContentResult");
    SEL factory = sel_registerName("resultWithIdentifier:title:subtitle:summary:auxiliaryTitle:auxiliarySubtitle:actionURL:searchableContent:");
    if (!resultClass || ![resultClass respondsToSelector:factory]) {
        NSLog(@"CharonSearchDatastore: SPContentResult's result factory is unavailable (class %@)", resultClass);
        return [NSArray array];
    }
    for (id item in items) {
        id attributeSet = [item valueForKey:@"attributeSet"];
        // CSSearchableItemAttributeSet.m in this port does not carry contentDescription (measured
        // on device: an unentitled valueForKey: on it raises NSUnknownKeyException, not answers
        // nil) - title is the only field this port's attribute set actually backs, so it is the
        // only one matched against.
        NSString *title = [attributeSet valueForKey:@"title"] ?: @"";
        if ([title rangeOfString:searchString options:NSCaseInsensitiveSearch].location == NSNotFound)
            continue;
        NSString *identifier = [item valueForKey:@"uniqueIdentifier"];
        id result = ((id (*)(id, SEL, id, id, id, id, id, id, id, id))objc_msgSend)(
            resultClass, factory, identifier, title, nil, nil, nil, nil, nil, nil);
        if (result)
            [results addObject:result];
    }
    return results;
}

static id CharonDisplayIdentifierForDomain(id self, SEL _cmd, unsigned int domain)
{
    return @"Charon";
}

static id CharonSearchDomains(id self, SEL _cmd)
{
    return @[@999];
}

static void CharonPerformQuery(id self, SEL _cmd, id query, id resultsPipe)
{
    NSArray *matches = CharonSearchMatches(query);
    // Measured on device: the object handed to withResultsPipe: is the query object itself
    // (an SDSearchQuery, defined in searchd's own binary, not the shared cache - not
    // SPSearchResultSection, which was a strings-proximity guess and never checked against what
    // this parameter's real class actually answers to). Its real, required protocol is
    // <SPSearchResultsPipe>, and the push method is -appendResults:, not -addResults: -
    // SPSearchResultSection happens to implement a same-shaped -addResults: for an unrelated
    // reason, which is exactly how a wrong name keeps looking plausible.
    if (matches.count == 0 || !resultsPipe)
        return;
    ((void (*)(id, SEL, id))objc_msgSend)(resultsPipe, sel_registerName("appendResults:"), matches);
}

__attribute__((constructor))
static void CharonSearchDatastoreRegister(void)
{
    if (NSClassFromString(@"CharonSearchDatastore"))
        return;
    // SPSearchDatastore is a protocol, not a class - NSClassFromString on it answers nil and a
    // plain NSObject fallback is not what NotesDatastore itself subclasses, which is why searchd
    // silently ignored one (measured on device: no crash, no error, -searchDomains simply never
    // called). NotesDatastore's own binary imports _OBJC_CLASS_$_SPContentResult and nothing else
    // SP-prefixed (macho.imported_symbols), so that is the real base class.
    Class base = NSClassFromString(@"SPContentResult") ?: [NSObject class];
    Class cls = objc_allocateClassPair(base, "CharonSearchDatastore", 0);
    if (!cls) {
        NSLog(@"CharonSearchDatastore: objc_allocateClassPair over %@ failed", base);
        return;
    }
    class_addMethod(cls, sel_registerName("displayIdentifierForDomain:"), (IMP)CharonDisplayIdentifierForDomain, "@12@0:4I8");
    class_addMethod(cls, sel_registerName("searchDomains"), (IMP)CharonSearchDomains, "@8@0:4");
    class_addMethod(cls, sel_registerName("performQuery:withResultsPipe:"), (IMP)CharonPerformQuery, "v16@0:4@8@12");
    // objc_allocateClassPair over SPContentResult does not itself grant <SPSearchDatastore>
    // conformance - NotesDatastore gets it from its own @interface declaration, which
    // class_addMethod alone does not reproduce. The identical gap already cost one silent failure
    // this pass, on the delegate side (SPDaemonQueryDelegate, fixed the same way in
    // searchbundle-probe.m) - applying it here too rather than assuming the method list alone is
    // enough a second time.
    Protocol *protocol = objc_getProtocol("SPSearchDatastore");
    if (protocol)
        class_addProtocol(cls, protocol);
    else
        NSLog(@"CharonSearchDatastore: this release has no SPSearchDatastore protocol; searchd will not query this datastore");
    objc_registerClassPair(cls);
}
