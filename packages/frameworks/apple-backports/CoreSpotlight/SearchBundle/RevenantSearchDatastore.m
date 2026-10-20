#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "../RevenantSpotlightStore.h"

#ifndef REVENANT_BACKPORTS_INSTALL_FOLDER
#error "REVENANT_BACKPORTS_INSTALL_FOLDER must be defined by write_searchbundle"
#endif

static void RevenantSearchLoadClasses(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *library = [@REVENANT_BACKPORTS_INSTALL_FOLDER stringByAppendingPathComponent:@"libCoreSpotlightBackports.dylib"];
        if (!dlopen(library.fileSystemRepresentation, RTLD_LAZY))
            NSLog(@"RevenantSearchDatastore: cannot load %@: %s", library, dlerror());
    });
}

static NSArray *RevenantSearchLoadAllItems(void)
{
    RevenantSearchLoadClasses();
    Class itemClass = NSClassFromString(@"CSSearchableItem");
    if (!itemClass) {
        NSLog(@"RevenantSearchDatastore: CSSearchableItem is not registered; no indexed item can be read");
        return [NSArray array];
    }
    NSMutableArray *items = [NSMutableArray array];
    NSFileManager *files = [NSFileManager defaultManager];
    for (NSString *application in [files contentsOfDirectoryAtPath:REVENANT_SPOTLIGHT_SHARED_ROOT error:NULL]) {
        NSString *appDirectory = [REVENANT_SPOTLIGHT_SHARED_ROOT stringByAppendingPathComponent:application];
        for (NSString *name in [files contentsOfDirectoryAtPath:appDirectory error:NULL]) {
            if (![name.pathExtension isEqualToString:@"plist"])
                continue;
            NSString *file = [appDirectory stringByAppendingPathComponent:name];
            NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:file];
            id entries = disk[@"entries"];
            if (![entries isKindOfClass:[NSDictionary class]]) {
                NSLog(@"RevenantSearchDatastore: rejected %@: %@", file, disk ? [NSString stringWithFormat:@"its entries are %@, not a dictionary", entries ? [NSString stringWithFormat:@"a %@", [entries class]] : @"missing"] : @"not a property list dictionary");
                continue;
            }
            for (id key in entries) {
                id archived = entries[key];
                if (![archived isKindOfClass:[NSData class]]) {
                    NSLog(@"RevenantSearchDatastore: rejected entry %@ of %@: a %@, not archive data", key, file, [archived class]);
                    continue;
                }
                id item = nil;
                @try {
                    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archived];
                    unarchiver.requiresSecureCoding = YES;
                    item = [unarchiver decodeObjectOfClass:itemClass forKey:@"root"];
                    [unarchiver finishDecoding];
                } @catch (NSException *exception) {
                    NSLog(@"RevenantSearchDatastore: rejected entry %@ of %@: %@: %@", key, file, exception.name, exception.reason);
                    continue;
                }
                if (![item isKindOfClass:itemClass]) {
                    NSLog(@"RevenantSearchDatastore: rejected entry %@ of %@: it decodes to no %@ (%@)", key, file, itemClass, item ? NSStringFromClass([item class]) : @"nothing");
                    continue;
                }
                [items addObject:item];
            }
        }
    }
    return items;
}

static NSArray *RevenantSearchMatches(id query)
{
    SEL getter = sel_registerName("searchString");
    if (![query respondsToSelector:getter]) {
        NSLog(@"RevenantSearchDatastore: the query, a %@, has no -searchString; this datastore cannot answer it", [query class]);
        return [NSArray array];
    }
    NSString *searchString = ((id (*)(id, SEL))objc_msgSend)(query, getter);
    if (searchString.length == 0)
        return [NSArray array];
    NSArray *items = RevenantSearchLoadAllItems();
    NSMutableArray *results = [NSMutableArray array];
    Class resultClass = NSClassFromString(@"SPContentResult");
    SEL factory = sel_registerName("resultWithIdentifier:title:subtitle:summary:auxiliaryTitle:auxiliarySubtitle:actionURL:searchableContent:");
    if (!resultClass || ![resultClass respondsToSelector:factory]) {
        NSLog(@"RevenantSearchDatastore: SPContentResult's result factory is unavailable (class %@)", resultClass);
        return [NSArray array];
    }
    for (id item in items) {
        id attributeSet = [item valueForKey:@"attributeSet"];
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

static id RevenantDisplayIdentifierForDomain(id self, SEL _cmd, unsigned int domain)
{
    return @"Revenant";
}

static id RevenantSearchDomains(id self, SEL _cmd)
{
    return @[@999];
}

static void RevenantPerformQuery(id self, SEL _cmd, id query, id resultsPipe)
{
    NSArray *matches = RevenantSearchMatches(query);
    if (matches.count == 0 || !resultsPipe)
        return;
    ((void (*)(id, SEL, id))objc_msgSend)(resultsPipe, sel_registerName("appendResults:"), matches);
}

__attribute__((constructor))
static void RevenantSearchDatastoreRegister(void)
{
    if (NSClassFromString(@"RevenantSearchDatastore"))
        return;
    Class base = NSClassFromString(@"SPContentResult") ?: [NSObject class];
    Class cls = objc_allocateClassPair(base, "RevenantSearchDatastore", 0);
    if (!cls) {
        NSLog(@"RevenantSearchDatastore: objc_allocateClassPair over %@ failed", base);
        return;
    }
    class_addMethod(cls, sel_registerName("displayIdentifierForDomain:"), (IMP)RevenantDisplayIdentifierForDomain, "@12@0:4I8");
    class_addMethod(cls, sel_registerName("searchDomains"), (IMP)RevenantSearchDomains, "@8@0:4");
    class_addMethod(cls, sel_registerName("performQuery:withResultsPipe:"), (IMP)RevenantPerformQuery, "v16@0:4@8@12");
    Protocol *protocol = objc_getProtocol("SPSearchDatastore");
    if (protocol)
        class_addProtocol(cls, protocol);
    else
        NSLog(@"RevenantSearchDatastore: this release has no SPSearchDatastore protocol; searchd will not query this datastore");
    objc_registerClassPair(cls);
}
