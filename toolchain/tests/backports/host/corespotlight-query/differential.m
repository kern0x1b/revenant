#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>

static CSSearchableItem *item(NSString *identifier, NSString *title, NSString *description)
{
    CSSearchableItemAttributeSet *attributes = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.text"];
    attributes.title = title;
    attributes.displayName = description;
    return [[CSSearchableItem alloc] initWithUniqueIdentifier:identifier domainIdentifier:@"revenant.query.differential" attributeSet:attributes];
}

static void query(NSString *label, NSString *text, NSArray<NSString *> *attributes)
{
    __block NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    __block NSUInteger batches = 0;
    __block NSMutableDictionary<NSString *, NSString *> *described = [NSMutableDictionary dictionary];
    __block NSUInteger countAtCompletion = 0;
    __block NSString *error = @"none";
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    CSSearchQuery *search = [[CSSearchQuery alloc] initWithQueryString:text attributes:attributes];
    search.foundItemsHandler = ^(NSArray<CSSearchableItem *> *items) {
        batches++;
        for (CSSearchableItem *found in items) {
            [identifiers addObject:found.uniqueIdentifier];
            described[found.uniqueIdentifier] = [NSString stringWithFormat:@"title=%@ desc=%@ type=%@", found.attributeSet.title ?: @"nil",
                                                 found.attributeSet.displayName ?: @"nil", found.attributeSet.contentType ?: @"nil"];
        }
    };
    search.completionHandler = ^(NSError *e) {
        countAtCompletion = search.foundItemCount;
        if (e)
            error = [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code];
        dispatch_semaphore_signal(done);
    };
    [search start];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    NSArray<NSString *> *sorted = [identifiers sortedArrayUsingSelector:@selector(compare:)];
    NSString *first = sorted.count > 0 ? described[sorted.firstObject] : @"-";
    printf("%-22s | found=%s | batches=%lu | count=%lu | error=%s | first=%s\n", label.UTF8String,
           [[sorted componentsJoinedByString:@","] UTF8String], (unsigned long)batches, (unsigned long)countAtCompletion,
           error.UTF8String, first.UTF8String);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSArray<CSSearchableItem *> *items = @[
            item(@"revenant.query.a", @"Revenant Alpha Q", @"zzuniqueword body"),
            item(@"revenant.query.b", @"revenant beta Q", @"plain text"),
            item(@"revenant.query.c", @"Gamma Q", @"plain text"),
        ];
        dispatch_semaphore_t indexed = dispatch_semaphore_create(0);
        [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:items completionHandler:^(NSError *e) {
            printf("index: %s\n", e ? e.description.UTF8String : "none");
            dispatch_semaphore_signal(indexed);
        }];
        dispatch_semaphore_wait(indexed, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        [NSThread sleepForTimeInterval:5];

        NSArray<NSString *> *title = @[@"title"];
        query(@"exact", @"title == \"Revenant Alpha Q\"", title);
        query(@"exact lowercase", @"title == \"revenant alpha q\"", title);
        query(@"prefix wildcard", @"title == \"Revenant*Q\"", title);
        query(@"substring wildcard", @"title == \"*Alpha*\"", title);
        query(@"suffix wildcard", @"title == \"*Q\"", title);
        query(@"star only", @"title == \"*\"", title);
        query(@"description exact", @"displayName == \"zzuniqueword body\"", @[@"displayName"]);
        query(@"description word", @"displayName == \"zzuniqueword\"", @[@"displayName"]);
        query(@"not equal", @"title != \"Revenant Alpha Q\"", title);
        query(@"or", @"title == \"Revenant Alpha Q\" || title == \"Gamma Q\"", title);
        query(@"parens and", @"(title == \"Revenant*\" || title == \"Gamma Q\") && displayName == \"plain text\"", title);
        query(@"precedence", @"title == \"Revenant Alpha Q\" || title == \"Gamma Q\" && displayName == \"plain text\"", title);
        query(@"question mark", @"title == \"Gamm? Q\"", title);
        query(@"content type", @"contentType == \"public.text\"", title);
        query(@"unknown attribute", @"nosuchattr == \"x\"", title);
        query(@"free text", @"Alpha", title);
        query(@"contains", @"title contains \"Alpha\"", title);
        query(@"unfinished", @"title ==", title);
        query(@"unclosed quote", @"title == \"Alpha", title);
        query(@"attrs nil", @"title == \"Gamma Q\"", nil);
        query(@"attrs empty", @"title == \"Gamma Q\"", @[]);
        query(@"attrs title", @"title == \"Gamma Q\"", title);
        query(@"attrs both", @"title == \"Gamma Q\"", @[@"title", @"displayName"]);

        dispatch_semaphore_t removed = dispatch_semaphore_create(0);
        [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithIdentifiers:@[@"revenant.query.a", @"revenant.query.b", @"revenant.query.c"]
                                                                       completionHandler:^(NSError *e) {
            printf("cleanup: %s\n", e ? e.description.UTF8String : "none");
            dispatch_semaphore_signal(removed);
        }];
        dispatch_semaphore_wait(removed, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
    }
    return 0;
}
