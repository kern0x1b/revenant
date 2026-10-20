#import <UIKit/UIKit.h>

@implementation UIDropProposal {
    UIDropOperation _operation;
    BOOL _precise;
    BOOL _prefersFullSizePreview;
}

- (instancetype)initWithDropOperation:(UIDropOperation)operation
{
    self = [super init];
    if (self) {
        _operation = operation;
        _prefersFullSizePreview = YES;
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

- (BOOL)prefersFullSizePreview
{
    return _prefersFullSizePreview;
}

- (void)setPrefersFullSizePreview:(BOOL)prefersFullSizePreview
{
    _prefersFullSizePreview = prefersFullSizePreview;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIDropProposal *copy = [[[self class] allocWithZone:zone] initWithDropOperation:self.operation];
    copy.precise = self.isPrecise;
    copy.prefersFullSizePreview = self.prefersFullSizePreview;
    return copy;
}

@end
