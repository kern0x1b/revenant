#import <UIKit/UIKit.h>

@implementation UIDropProposal {
    UIDropOperation _operation;
    BOOL _precise;
}

- (instancetype)initWithDropOperation:(UIDropOperation)operation
{
    self = [super init];
    if (self) {
        _operation = operation;
    }
    return self;
}

- (UIDropOperation)operation
{
    return _operation;
}

- (BOOL)isPrecise
{
    return _precise;
}

- (void)setPrecise:(BOOL)precise
{
    _precise = precise;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIDropProposal *copy = [[[self class] allocWithZone:zone] initWithDropOperation:self.operation];
    copy.precise = self.isPrecise;
    copy.prefersFullSizePreview = self.prefersFullSizePreview;
    return copy;
}

@end
