#import "RevenantMenus.h"

NSString *const UIActivityItemsConfigurationInteractionShare = @"share";
NSString *const UIActivityItemsConfigurationMetadataKeyTitle = @"title";
NSString *const UIActivityItemsConfigurationMetadataKeyMessageBody = @"messageBody";
NSString *const UIActivityItemsConfigurationPreviewIntentFullSize = @"fullSize";
NSString *const UIActivityItemsConfigurationPreviewIntentThumbnail = @"thumbnail";

@implementation UIActivityItemsConfiguration {
@private
    NSArray *_objects;
    NSArray *_itemProviders;
    id _localObject;
    NSArray *_supportedInteractions;
    id (^_metadataProvider)(UIActivityItemsConfigurationMetadataKey);
    id (^_perItemMetadataProvider)(NSInteger, UIActivityItemsConfigurationMetadataKey);
    NSItemProvider *(^_previewProvider)(NSInteger, UIActivityItemsConfigurationPreviewIntent, CGSize);
    NSArray<UIActivity *> *(^_applicationActivitiesProvider)(void);
}

+ (instancetype)activityItemsConfigurationWithObjects:(NSArray *)objects
{
    return [[self alloc] initWithObjects:objects];
}

+ (instancetype)activityItemsConfigurationWithItemProviders:(NSArray *)itemProviders
{
    return [[self alloc] initWithItemProviders:itemProviders];
}

- (instancetype)init
{
    return [self initWithItemProviders:@[]];
}

- (instancetype)initWithObjects:(NSArray *)objects
{
    if (!objects)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIActivityItemsConfiguration initWithObjects:]: objects parameter cannot be nil."];
    if ((self = [super init])) {
        _objects = [objects copy];
        _supportedInteractions = @[UIActivityItemsConfigurationInteractionShare];
        [self itemProvidersForActivityItemsConfiguration];
    }
    return self;
}

- (instancetype)initWithItemProviders:(NSArray *)itemProviders
{
    if ((self = [super init])) {
        _itemProviders = [itemProviders copy];
        _supportedInteractions = @[UIActivityItemsConfigurationInteractionShare];
    }
    return self;
}

- (id)localObject
{
    return _localObject;
}

- (void)setLocalObject:(id)localObject
{
    _localObject = localObject;
}

- (NSArray *)supportedInteractions
{
    return _supportedInteractions;
}

- (void)setSupportedInteractions:(NSArray *)supportedInteractions
{
    _supportedInteractions = [supportedInteractions copy];
}

- (id (^)(UIActivityItemsConfigurationMetadataKey))metadataProvider
{
    return _metadataProvider;
}

- (void)setMetadataProvider:(id (^)(UIActivityItemsConfigurationMetadataKey))metadataProvider
{
    _metadataProvider = [metadataProvider copy];
}

- (id (^)(NSInteger, UIActivityItemsConfigurationMetadataKey))perItemMetadataProvider
{
    return _perItemMetadataProvider;
}

- (void)setPerItemMetadataProvider:(id (^)(NSInteger, UIActivityItemsConfigurationMetadataKey))perItemMetadataProvider
{
    _perItemMetadataProvider = [perItemMetadataProvider copy];
}

- (NSItemProvider *(^)(NSInteger, UIActivityItemsConfigurationPreviewIntent, CGSize))previewProvider
{
    return _previewProvider;
}

- (void)setPreviewProvider:(NSItemProvider *(^)(NSInteger, UIActivityItemsConfigurationPreviewIntent, CGSize))previewProvider
{
    _previewProvider = [previewProvider copy];
}

- (NSArray<UIActivity *> *(^)(void))applicationActivitiesProvider
{
    return _applicationActivitiesProvider;
}

- (void)setApplicationActivitiesProvider:(NSArray<UIActivity *> *(^)(void))applicationActivitiesProvider
{
    _applicationActivitiesProvider = [applicationActivitiesProvider copy];
}

- (NSArray<NSItemProvider *> *)itemProvidersForActivityItemsConfiguration
{
    if (_itemProviders)
        return _itemProviders;
    NSMutableArray *providers = [NSMutableArray arrayWithCapacity:_objects.count];
    for (id object in _objects)
        [providers addObject:[[NSItemProvider alloc] initWithObject:object]];
    return providers;
}

- (BOOL)activityItemsConfigurationSupportsInteraction:(UIActivityItemsConfigurationInteraction)interaction
{
    return [_supportedInteractions containsObject:interaction];
}

- (id)activityItemsConfigurationMetadataForKey:(UIActivityItemsConfigurationMetadataKey)key
{
    return _metadataProvider ? _metadataProvider(key) : nil;
}

- (id)activityItemsConfigurationMetadataForItemAtIndex:(NSInteger)index key:(UIActivityItemsConfigurationMetadataKey)key
{
    return _perItemMetadataProvider ? _perItemMetadataProvider(index, key) : nil;
}

- (NSItemProvider *)activityItemsConfigurationPreviewForItemAtIndex:(NSInteger)index intent:(UIActivityItemsConfigurationPreviewIntent)intent suggestedSize:(CGSize)suggestedSize
{
    return _previewProvider ? _previewProvider(index, intent, suggestedSize) : nil;
}

- (NSArray<UIActivity *> *)applicationActivitiesForActivityItemsConfiguration
{
    return _applicationActivitiesProvider ? _applicationActivitiesProvider() : nil;
}

@end
