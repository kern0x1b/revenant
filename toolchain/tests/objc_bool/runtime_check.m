#import <Foundation/Foundation.h>
#import <string.h>

@interface RevenantFlagged : NSObject
@property (nonatomic) BOOL on;
@end

@implementation RevenantFlagged
@end

static int failures = 0;

static void check(int ok, const char *what)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        RevenantFlagged *object = [RevenantFlagged new];
        object.on = YES;
        check(object.on == YES, "a BOOL property stores YES");

        NSNumber *boxed = [object valueForKey:@"on"];
        printf("INFO: valueForKey boxes BOOL as objCType %s\n", boxed.objCType);
        check(boxed.boolValue == YES, "KVC reads a BOOL property as YES");

        [object setValue:@NO forKey:@"on"];
        check(object.on == NO, "KVC stores NO into a BOOL property");

        NSMethodSignature *signature = [object methodSignatureForSelector:@selector(setOn:)];
        printf("INFO: setOn: argument encoding %s\n", [signature getArgumentTypeAtIndex:2]);
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = object;
        invocation.selector = @selector(setOn:);
        BOOL yes = YES;
        [invocation setArgument:&yes atIndex:2];
        [invocation invoke];
        check(object.on == YES, "NSInvocation passes a BOOL argument");

        BOOL read = NO;
        NSMethodSignature *getter = [object methodSignatureForSelector:@selector(on)];
        printf("INFO: on return encoding %s\n", [getter methodReturnType]);
        NSInvocation *reader = [NSInvocation invocationWithMethodSignature:getter];
        reader.target = object;
        reader.selector = @selector(on);
        [reader invoke];
        [reader getReturnValue:&read];
        check(read == YES, "NSInvocation returns a BOOL result");

        NSDictionary *dictionary = [NSDictionary dictionaryWithObject:@YES forKey:@"flag"];
        check([dictionary[@"flag"] boolValue] == YES, "a BOOL boxed in a collection reads back as YES");

        printf("failures %d\n", failures);
    }
    return failures == 0 ? 0 : 1;
}
