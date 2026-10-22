#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char RevenantSearchItemsKey;
static char RevenantOperationQueueKey;
static char RevenantForwardingKey;

NSArray *revenant_metadata_urls(NSArray *items);

NSArray *revenant_metadata_urls(NSArray *items)
{
    NSMutableArray *urls = [NSMutableArray array];
    for (id item in items) {
        NSURL *url = nil;
        if ([item isKindOfClass:[NSURL class]])
            url = item;
        else if ([item isKindOfClass:[NSString class]])
            url = [NSURL fileURLWithPath:item];
        else if ([item isKindOfClass:[NSMetadataItem class]]) {
            id found = [item valueForAttribute:NSMetadataItemURLKey];
            if ([found isKindOfClass:[NSURL class]])
                url = found;
            else if ([found isKindOfClass:[NSString class]])
                url = [NSURL fileURLWithPath:found];
        }
        if (url.isFileURL)
            [urls addObject:url];
    }
    return urls;
}

@implementation NSMetadataQuery (RevenantItems7)

- (NSArray *)searchItems
{
    return objc_getAssociatedObject(self, &RevenantSearchItemsKey);
}

- (void)setSearchItems:(NSArray *)searchItems
{
    if (objc_getAssociatedObject(self, &RevenantForwardingKey))
        return;
    objc_setAssociatedObject(self, &RevenantSearchItemsKey, [searchItems copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SEL setter = NSSelectorFromString(@"setSearchItemURLs:");
    if ([self respondsToSelector:setter]) {
        objc_setAssociatedObject(self, &RevenantForwardingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self performSelector:setter withObject:searchItems ? revenant_metadata_urls(searchItems) : nil];
        objc_setAssociatedObject(self, &RevenantForwardingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NSOperationQueue *)operationQueue
{
    return objc_getAssociatedObject(self, &RevenantOperationQueueKey);
}

- (void)setOperationQueue:(NSOperationQueue *)operationQueue
{
    objc_setAssociatedObject(self, &RevenantOperationQueueKey, operationQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
