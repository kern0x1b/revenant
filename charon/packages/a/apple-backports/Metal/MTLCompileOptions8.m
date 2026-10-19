#import "CharonMetal.h"


@implementation MTLCompileOptions

- (instancetype)init
{
    if ((self = [super init]))
        self.fastMathEnabled = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLCompileOptions *copy = [[MTLCompileOptions alloc] init];
    copy.preprocessorMacros = self.preprocessorMacros;
    copy.fastMathEnabled = self.fastMathEnabled;
    copy.languageVersion = self.languageVersion;
    return copy;
}

@end
