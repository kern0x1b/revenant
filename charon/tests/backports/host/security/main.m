#import <Foundation/Foundation.h>
#import <stdio.h>
#import "security-cases.h"

static void record(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        security_run(record);
    }
    return 0;
}
