#define FX_WRAPPED(CLASS) \
@implementation CLASS (FXWrapped) \
- (void)fx_wrapped \
{ \
} \
@end

@implementation FXProperties

@synthesize fx_first = _fx_first, fx_second, fx_third = _fx_third;

@end

FX_WRAPPED(FXMacroOne)
FX_WRAPPED(FXMacroTwo)
