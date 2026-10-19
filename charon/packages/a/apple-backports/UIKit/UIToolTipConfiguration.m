#import <UIKit/UIKit.h>

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
