#import "CharonMenus.h"

@interface CharonProviderItem : NSObject <UIActivityItemSource>
- (instancetype)initWithProvider:(NSItemProvider *)provider;
@end

@implementation CharonProviderItem {
@private
    NSItemProvider *_provider;
}

- (instancetype)initWithProvider:(NSItemProvider *)provider
{
    if ((self = [super init]))
        _provider = provider;
    return self;
}

- (Class)charon_class
{
    for (Class candidate in @[[NSURL class], [NSString class]]) {
        if ([_provider canLoadObjectOfClass:candidate])
            return candidate;
    }
    return Nil;
}

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
    Class kind = [self charon_class];
    if (kind == [NSURL class])
        return [NSURL URLWithString:@"about:blank"];
    return @"";
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
    Class kind = [self charon_class];
    if (!kind)
        return nil;
    __block id loaded = nil;
    __block BOOL done = NO;
    [_provider loadObjectOfClass:kind completionHandler:^(id object, NSError *error) {
        loaded = object;
        done = YES;
    }];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return loaded;
}

@end

@implementation UIActivityViewController (CharonItemsConfiguration)

- (instancetype)initWithActivityItemsConfiguration:(id<UIActivityItemsConfigurationReading>)activityItemsConfiguration
{
    NSMutableArray *items = [NSMutableArray array];
    for (NSItemProvider *provider in activityItemsConfiguration.itemProvidersForActivityItemsConfiguration)
        [items addObject:[[CharonProviderItem alloc] initWithProvider:provider]];
    NSArray *activities = nil;
    if ([activityItemsConfiguration respondsToSelector:@selector(applicationActivitiesForActivityItemsConfiguration)])
        activities = activityItemsConfiguration.applicationActivitiesForActivityItemsConfiguration;
    return [self initWithActivityItems:items applicationActivities:activities];
}

@end
