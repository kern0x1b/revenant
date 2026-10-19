#import <Foundation/Foundation.h>
#import "check.h"

int main(void)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSUserActivity");
        CHECK(ours != Nil, "the port defines the class");
        id port = [[ours alloc] initWithActivityType:@"com.example.a"];
        NSUserActivity *system = [[NSUserActivity alloc] initWithActivityType:@"com.example.a"];
        CHECK([port targetContentIdentifier] == nil && system.targetContentIdentifier == nil, "there is no target content identifier to begin with");
        NSMutableString *text = [NSMutableString stringWithString:@"one"];
        [port setTargetContentIdentifier:text];
        system.targetContentIdentifier = text;
        [text appendString:@"two"];
        CHECK_EQUAL([port targetContentIdentifier], system.targetContentIdentifier, "the identifier is copied, so changing the string later does not change it");
        CHECK_EQUAL([port targetContentIdentifier], @"one", "and it is the copy that was made");
        [port setTargetContentIdentifier:@""];
        system.targetContentIdentifier = @"";
        CHECK_EQUAL([port targetContentIdentifier], system.targetContentIdentifier, "an empty identifier is kept");
        [port setTargetContentIdentifier:nil];
        system.targetContentIdentifier = nil;
        CHECK([port targetContentIdentifier] == nil && system.targetContentIdentifier == nil, "and nil takes it away");
        id other = [[ours alloc] initWithActivityType:@"com.example.b"];
        [port setTargetContentIdentifier:@"x"];
        CHECK([other targetContentIdentifier] == nil, "each activity has its own");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
