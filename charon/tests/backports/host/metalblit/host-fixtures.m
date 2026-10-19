// host-fixtures.m — the two classes the port's buffer files name and this test cannot have.
//
// CharonMetalDevice makes an EAGL context and CharonMetalTexture is an OpenGL ES 2.0 texture, and
// Catalyst has neither, so the two cannot be the port's own here. Nothing on the paths under test
// reaches either, and these two classes exist to make that true *loudly*: every entry point raises
// rather than answering, so a buffer blit that ever started to touch a device or a texture would
// abort this test instead of quietly being compared against a stand-in that agrees with it.
//
// Compiled with the same class renames as the port's own objects, so these are the names the port
// under test links against.
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
