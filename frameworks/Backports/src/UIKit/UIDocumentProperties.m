#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIDocumentProperties {
    id _metadata;
    NSArray<UIDragItem *> *(^_dragItemsProvider)(id<UIDragSession>);
    UIActivityViewController *(^_activityViewControllerProvider)(void);
    BOOL _wantsIconRepresentation;
}

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init])) {
        Class metadata = NSClassFromString(@"LPLinkMetadata");
        _metadata = [[metadata alloc] init];
        [_metadata setValue:url forKey:@"originalURL"];
        [_metadata setValue:url forKey:@"URL"];
    }
    return self;
}

- (instancetype)initWithMetadata:(LPLinkMetadata *)metadata
{
    if ((self = [super init]))
        _metadata = [(id)metadata copy];
    return self;
}

- (LPLinkMetadata *)metadata
{
    return _metadata;
}

- (void)setMetadata:(LPLinkMetadata *)metadata
{
    _metadata = [(id)metadata copy];
}

- (NSArray<UIDragItem *> *(^)(id<UIDragSession>))dragItemsProvider
{
    return _dragItemsProvider;
}

- (void)setDragItemsProvider:(NSArray<UIDragItem *> *(^)(id<UIDragSession>))dragItemsProvider
{
    _dragItemsProvider = [dragItemsProvider copy];
}

- (UIActivityViewController *(^)(void))activityViewControllerProvider
{
    return _activityViewControllerProvider;
}

- (void)setActivityViewControllerProvider:(UIActivityViewController *(^)(void))activityViewControllerProvider
{
    _activityViewControllerProvider = [activityViewControllerProvider copy];
}

- (BOOL)wantsIconRepresentation
{
    return _wantsIconRepresentation;
}

- (void)setWantsIconRepresentation:(BOOL)wantsIconRepresentation
{
    _wantsIconRepresentation = wantsIconRepresentation;
}

@end
