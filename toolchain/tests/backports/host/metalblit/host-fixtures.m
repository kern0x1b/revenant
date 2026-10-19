#import <Foundation/Foundation.h>

static void RevenantMetalHostFixtureRefuses(NSString *what)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Metal's host differential: %@ is not something the buffer paths under test may touch, because the object here is a fixture that refuses, not the port's own", what];
}

@implementation RevenantMetalDevice : NSObject

+ (id)shared
{
    RevenantMetalHostFixtureRefuses(@"RevenantMetalDevice +shared");
    return nil;
}

- (id)init
{
    RevenantMetalHostFixtureRefuses(@"-[RevenantMetalDevice init]");
    return nil;
}

@end

@implementation RevenantMetalTexture : NSObject

- (id)init
{
    RevenantMetalHostFixtureRefuses(@"-[RevenantMetalTexture init]");
    return nil;
}

@end
