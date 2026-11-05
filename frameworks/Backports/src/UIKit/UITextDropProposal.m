#import <UIKit/UIKit.h>

@implementation UITextDropProposal

- (instancetype)initWithDropOperation:(UIDropOperation)operation
{
    if ((self = [super initWithDropOperation:operation]))
        self.precise = YES;
    return self;
}

@end
