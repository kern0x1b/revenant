
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

id objc_allocWithZone(Class);
id objc_opt_self(id);

static int zoned;

@interface Answering : NSObject
@end

@implementation Answering
- (instancetype)self
{
    return nil;
}
@end

@interface Counted : NSObject
@property int value;
@end

@implementation Counted
+ (instancetype)allocWithZone:(NSZone *)zone
{
    zoned++;
    return [super allocWithZone:zone];
}
@end

int main(void)
{
    int fails = 0;
    id (*darwin)(Class) = dlsym(RTLD_DEFAULT, "objc_allocWithZone");
    id mine = [objc_allocWithZone([Counted class]) init];
    id theirs = [darwin([Counted class]) init];
    if (![mine isKindOfClass:[Counted class]] || [theirs class] != [mine class] || zoned != 2) {
        printf("FAIL  objc_allocWithZone allocates through the class's +allocWithZone:, as Darwin's does\n");
        fails++;
    }
    if (objc_allocWithZone(Nil) != nil || darwin(Nil) != nil) {
        printf("FAIL  objc_allocWithZone of Nil answers nil\n");
        fails++;
    }

    id (*darwin_self)(id) = dlsym(RTLD_DEFAULT, "objc_opt_self");
    Counted *counted = [Counted new];
    if (objc_opt_self((id)[Counted class]) != (id)[Counted class] || objc_opt_self(counted) != counted ||
        objc_opt_self(nil) != nil || objc_opt_self(@42) != @42) {
        printf("FAIL  objc_opt_self answers the class, the object, nil and a tagged pointer themselves\n");
        fails++;
    }
    Answering *answering = [Answering new];
    if (objc_opt_self(answering) != darwin_self(answering)) {
        printf("FAIL  objc_opt_self answers what -self answers where the class overrides it, as Darwin's does\n");
        fails++;
    }
    return fails;
}
