#import <UIKit/UIKit.h>

// The SDK marks -init and +new unavailable: the only public constructor is the factory. -init still answers
// the runtime's state (a nil identifier, a zero point, an automatic arrow), which the ivars' zero values give.
@implementation UIEditMenuConfiguration {
@private
    id<NSCopying> _identifier;
    CGPoint _sourcePoint;
    UIEditMenuArrowDirection _preferredArrowDirection;
}

+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint
{
    return [[self alloc] charon_initWithIdentifier:identifier sourcePoint:sourcePoint];
}

- (instancetype)charon_initWithIdentifier:(id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint
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
