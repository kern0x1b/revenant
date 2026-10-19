#import <UIKit/UIKit.h>
#import "uiviewinteractions-cases.h"

@interface InteractionProbe : NSObject <UIInteraction>
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableArray<NSString *> *moved;
@end

@implementation InteractionProbe
@synthesize view = _view;
@synthesize moved = _moved;

- (instancetype)init
{
    if ((self = [super init]))
        _moved = [NSMutableArray array];
    return self;
}

- (void)willMoveToView:(UIView *)view
{
    [_moved addObject:view ? @"will:view" : @"will:nil"];
}

- (void)didMoveToView:(UIView *)view
{
    [_moved addObject:view ? @"did:view" : @"did:nil"];
}
@end

static NSString *uiview_Describe(id value)
{
    NSUInteger count = [value isKindOfClass:[NSArray class]] ? [value count] : 0;
    return [NSString stringWithFormat:@"%lu", (unsigned long)count];
}

static NSString *uiview_Outcome(void (^block)(void))
{
    @try {
        block();
        return @"survived";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

void uiviewinteractions_run(UIViewInteractionsRecorder record)
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    InteractionProbe *interaction = [[InteractionProbe alloc] init];

    record(@"interactions.empty", uiview_Describe(view.interactions));
    record(@"interaction.movedBeforeAdd", [interaction.moved componentsJoinedByString:@","]);

    [view addInteraction:interaction];
    record(@"interactions.afterAdd", uiview_Describe(view.interactions));
    record(@"interaction.movedAfterAdd", [interaction.moved componentsJoinedByString:@","]);

    record(@"add.nil", uiview_Describe(nil) ? [NSString stringWithFormat:@"%@",
            uiview_Outcome(^{ [view addInteraction:nil]; })] : @"");
    NSUInteger before = view.interactions.count;
    [view addInteraction:interaction];
    record(@"reAdd.count", [NSString stringWithFormat:@"%lu->%lu", (unsigned long)before,
            (unsigned long)view.interactions.count]);
    record(@"reAdd.moved", [interaction.moved componentsJoinedByString:@","]);

    record(@"remove.other", uiview_Outcome(^{ [view removeInteraction:[[InteractionProbe alloc] init]]; }));
    record(@"interactions.afterRemoveOther", uiview_Describe(view.interactions));
    record(@"remove.nil", uiview_Outcome(^{ [view removeInteraction:nil]; }));

    [view removeInteraction:interaction];
    record(@"interactions.afterRemove", uiview_Describe(view.interactions));
    record(@"interaction.movedAfterRemove", [interaction.moved componentsJoinedByString:@","]);

    record(@"setNil", uiview_Outcome(^{ view.interactions = nil; }));

    UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    InteractionProbe *moving = [[InteractionProbe alloc] init];
    [other addInteraction:moving];
    [view addInteraction:moving];
    record(@"moveFromOther.view", [NSString stringWithFormat:@"%lu", (unsigned long)other.interactions.count]);
    record(@"moveFromOther.other", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
}
