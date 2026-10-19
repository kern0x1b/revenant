#import <Foundation/Foundation.h>

static void CharonMetalHostFixtureRefuses(NSString *what)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Metal's host differential: %@ is not something the buffer paths under test may touch, because the object here is a fixture that refuses, not the port's own", what];
}

@implementation CharonMetalDevice : NSObject

+ (id)shared
{
    CharonMetalHostFixtureRefuses(@"CharonMetalDevice +shared");
    return nil;
}

- (id)init
{
    CharonMetalHostFixtureRefuses(@"-[CharonMetalDevice init]");
    return nil;
}

@end

@implementation CharonMetalTexture : NSObject

- (id)init
{
    CharonMetalHostFixtureRefuses(@"-[CharonMetalTexture init]");
    return nil;
}

@end
