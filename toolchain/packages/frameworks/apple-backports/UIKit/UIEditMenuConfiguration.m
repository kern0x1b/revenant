#import <UIKit/UIKit.h>

@implementation UIEditMenuConfiguration {
@private
    id<NSCopying> _identifier;
    CGPoint _sourcePoint;
    UIEditMenuArrowDirection _preferredArrowDirection;
}

+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint
{
    return [[self alloc] revenant_initWithIdentifier:identifier sourcePoint:sourcePoint];
}

- (instancetype)revenant_initWithIdentifier:(id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint
{
    [super init];
    _identifier = identifier ? [(id)identifier copy] : [NSUUID UUID];
    _sourcePoint = sourcePoint;
    return self;
}

- (id<NSCopying>)identifier
{
    return _identifier;
}

- (CGPoint)sourcePoint
{
    return _sourcePoint;
}

- (UIEditMenuArrowDirection)preferredArrowDirection
{
    return _preferredArrowDirection;
}

- (void)setPreferredArrowDirection:(UIEditMenuArrowDirection)preferredArrowDirection
{
    _preferredArrowDirection = preferredArrowDirection;
}

@end
