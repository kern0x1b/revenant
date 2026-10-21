#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UICellConfigurationState (RevenantGetter14)

- (BOOL)editing
{
    return [self isEditing];
}

- (BOOL)expanded
{
    return [self isExpanded];
}

- (BOOL)reordering
{
    return [self isReordering];
}

- (BOOL)swiped
{
    return [self isSwiped];
}

@end
