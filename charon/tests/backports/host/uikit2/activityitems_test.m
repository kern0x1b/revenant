#import "uirest.h"

static NSArray *config_lines(Class cls, NSArray *(^interactions)(id), id (^makeObjects)(Class, NSArray *), id (^makeProviders)(Class, NSArray *))
{
    NSMutableArray *lines = [NSMutableArray array];
    UIActivityItemsConfiguration *c = makeObjects(cls, @[@"hello", [NSURL URLWithString:@"http://x"]]);
    [lines addObject:ur_line(@"defaults", @[interactions(c), c.localObject ?: @"nil", @(c.metadataProvider != nil), @(c.perItemMetadataProvider != nil), @(c.previewProvider != nil), @(c.applicationActivitiesProvider != nil)])];
    NSArray *providers = c.itemProvidersForActivityItemsConfiguration;
    NSMutableArray *types = [NSMutableArray array];
    for (NSItemProvider *provider in providers) {
        NSMutableArray *kept = [NSMutableArray array];
        for (NSString *type in provider.registeredTypeIdentifiers) {
            if (![type isEqualToString:@"public.file-url"])
                [kept addObject:type];
        }
        [types addObject:kept];
    }
    [lines addObject:ur_line(@"providers", @[@(providers.count), types, c.applicationActivitiesForActivityItemsConfiguration ?: @"nil"])];
    [lines addObject:ur_line(@"answers", @[@([c respondsToSelector:@selector(activityItemsConfigurationSupportsInteraction:)]), @([c respondsToSelector:@selector(activityItemsConfigurationMetadataForKey:)]),
                                          @([c respondsToSelector:@selector(activityItemsConfigurationMetadataForItemAtIndex:key:)]), @([c respondsToSelector:@selector(activityItemsConfigurationPreviewForItemAtIndex:intent:suggestedSize:)])])];
    [lines addObject:ur_line(@"supports", @[@([c activityItemsConfigurationSupportsInteraction:UIActivityItemsConfigurationInteractionShare]), @([c activityItemsConfigurationSupportsInteraction:@"x"])])];
    [lines addObject:ur_line(@"no providers", @[[c activityItemsConfigurationMetadataForKey:@"title"] ?: @"nil", [c activityItemsConfigurationMetadataForItemAtIndex:0 key:@"title"] ?: @"nil",
                                                [c activityItemsConfigurationPreviewForItemAtIndex:0 intent:UIActivityItemsConfigurationPreviewIntentThumbnail suggestedSize:CGSizeMake(10, 10)] ?: @"nil"])];
    c.metadataProvider = ^id(NSString *key) { return [key stringByAppendingString:@"!"]; };
    c.perItemMetadataProvider = ^id(NSInteger index, NSString *key) { return [NSString stringWithFormat:@"%ld%@", (long)index, key]; };
    c.previewProvider = ^NSItemProvider *(NSInteger index, NSString *intent, CGSize size) { return [[NSItemProvider alloc] initWithObject:[NSString stringWithFormat:@"%ld %@ %@", (long)index, intent, NSStringFromCGSize(size)]]; };
    c.applicationActivitiesProvider = ^NSArray *(void) { return @[]; };
    [lines addObject:ur_line(@"with providers", @[[c activityItemsConfigurationMetadataForKey:@"title"], [c activityItemsConfigurationMetadataForItemAtIndex:2 key:@"title"],
                                                 @([[c activityItemsConfigurationPreviewForItemAtIndex:1 intent:@"i" suggestedSize:CGSizeMake(1, 2)] registeredTypeIdentifiers].count), c.applicationActivitiesForActivityItemsConfiguration])];
    c.supportedInteractions = @[];
    [lines addObject:ur_line(@"none supported", @([c activityItemsConfigurationSupportsInteraction:UIActivityItemsConfigurationInteractionShare]))];
    c.localObject = @"local";
    [lines addObject:ur_line(@"local object", c.localObject)];
    [lines addObject:ur_raised(^id { return makeObjects(cls, @[[NSObject new]]); })];
    [lines addObject:ur_raised(^id { return makeObjects(cls, nil); })];
    [lines addObject:ur_raised(^id { return [makeProviders(cls, @[[[NSItemProvider alloc] init]]) itemProvidersForActivityItemsConfiguration]; })];
    NSMutableArray *held = [NSMutableArray arrayWithObject:@"a"];
    UIActivityItemsConfiguration *copied = makeObjects(cls, held);
    [held addObject:@"b"];
    [lines addObject:ur_line(@"objects are copied", @(copied.itemProvidersForActivityItemsConfiguration.count))];
    [lines addObject:ur_line(@"new", ur_raised(^id { return [[[cls alloc] performSelector:NSSelectorFromString(@"init")] class]; }))];
    [lines addObject:ur_line(@"init providers", ur_raised(^id { return [[[cls alloc] performSelector:NSSelectorFromString(@"init")] itemProvidersForActivityItemsConfiguration]; }))];
    return lines;
}

int main(void)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostUIActivityItemsConfiguration");
        charon_check(ours != Nil, "the port's configuration is linked under its host name", @"missing");
        NSArray *(^portInteractions)(id) = ^NSArray *(id c) { return [c supportedInteractions]; };
        NSArray *(^systemInteractions)(id) = ^NSArray *(id c) {
            NSMutableArray *kept = [NSMutableArray array];
            for (NSString *interaction in [c supportedInteractions]) {
                if (![interaction isEqualToString:@"copy"])
                    [kept addObject:interaction];
            }
            return kept;
        };
        id (^objects)(Class, NSArray *) = ^id(Class cls, NSArray *items) { return [cls activityItemsConfigurationWithObjects:items]; };
        id (^providers)(Class, NSArray *) = ^id(Class cls, NSArray *items) { return [cls activityItemsConfigurationWithItemProviders:items]; };
        ur_agree(@"configuration values", config_lines(ours, portInteractions, objects, providers), config_lines([UIActivityItemsConfiguration class], systemInteractions, objects, providers));
        NSString *(^constant)(const char *) = ^NSString *(const char *name) { return *(NSString *const *)dlsym(RTLD_DEFAULT, name); };
        charon_check([constant("CharonHostUIActivityItemsConfigurationInteractionShare") isEqualToString:UIActivityItemsConfigurationInteractionShare] &&
                         [constant("CharonHostUIActivityItemsConfigurationMetadataKeyTitle") isEqualToString:UIActivityItemsConfigurationMetadataKeyTitle] &&
                         [constant("CharonHostUIActivityItemsConfigurationMetadataKeyMessageBody") isEqualToString:UIActivityItemsConfigurationMetadataKeyMessageBody] &&
                         [constant("CharonHostUIActivityItemsConfigurationPreviewIntentFullSize") isEqualToString:UIActivityItemsConfigurationPreviewIntentFullSize] &&
                         [constant("CharonHostUIActivityItemsConfigurationPreviewIntentThumbnail") isEqualToString:UIActivityItemsConfigurationPreviewIntentThumbnail],
                     "the constants are the system's strings", @"one differs");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
