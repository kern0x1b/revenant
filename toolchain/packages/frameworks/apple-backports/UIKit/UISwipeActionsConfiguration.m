#import <UIKit/UIKit.h>

@implementation UISwipeActionsConfiguration {
    NSArray<UIContextualAction *> *_actions;
    BOOL _performsFirstActionWithFullSwipe;
}

+ (instancetype)configurationWithActions:(NSArray<UIContextualAction *> *)actions
{
    UISwipeActionsConfiguration *configuration = [[self alloc] init];
    configuration->_actions = actions;
    return configuration;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _performsFirstActionWithFullSwipe = YES;
    }
    return self;
}

- (NSArray<UIContextualAction *> *)actions
{
    return _actions;
}

- (BOOL)performsFirstActionWithFullSwipe
{
    return _performsFirstActionWithFullSwipe;
}

- (void)setPerformsFirstActionWithFullSwipe:(BOOL)performsFirstActionWithFullSwipe
{
    _performsFirstActionWithFullSwipe = performsFirstActionWithFullSwipe;
}

@end
