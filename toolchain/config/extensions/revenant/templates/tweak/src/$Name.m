#import <Foundation/Foundation.h>

__attribute__((constructor))
static void ${symbol}_loaded(void)
{
    NSLog(@"$Name loaded into %@", [[NSProcessInfo processInfo] processName]);
}
