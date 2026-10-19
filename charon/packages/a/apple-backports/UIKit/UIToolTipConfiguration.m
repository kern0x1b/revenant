#import <UIKit/UIKit.h>

// The SDK marks -init and +new unavailable: the factories are the constructors. -init still answers the runtime's state
// (a nil tool tip and a zero rectangle), which the ivars' zero values give. A factory without a rectangle applies the tool
// tip to the whole view, which the header names as CGRectNull.
@implementation UIToolTipConfiguration {
@private
    NSString *_toolTip;
    CGRect _sourceRect;
}

+ (instancetype)configurationWithToolTip:(NSString *)toolTip
{
    return [self configurationWithToolTip:toolTip inRect:CGRectNull];
}

+ (instancetype)configurationWithToolTip:(NSString *)toolTip inRect:(CGRect)sourceRect
{
    return [[self alloc] charon_initWithToolTip:toolTip inRect:sourceRect];
}

- (instancetype)charon_initWithToolTip:(NSString *)toolTip inRect:(CGRect)sourceRect
{
    [super init];
    _toolTip = [toolTip copy];
    _sourceRect = sourceRect;
    return self;
}

- (NSString *)toolTip
{
    return _toolTip;
}

- (CGRect)sourceRect
{
    return _sourceRect;
}

@end
