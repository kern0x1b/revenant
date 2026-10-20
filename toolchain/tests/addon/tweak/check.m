#import "check.h"

int revenant_failures;
int revenant_checks;

void revenant_check(BOOL passed, const char *name, NSString *detail)
{
    revenant_checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        revenant_failures++;
        printf("FAIL %s: %s\n", name, detail.UTF8String);
    }
    fflush(stdout);
}

static void revenant_uncaught(NSException *exception)
{
    printf("FAIL uncaught %s: %s\n%s\n", exception.name.UTF8String, exception.reason.UTF8String, [exception.callStackReturnAddresses description].UTF8String);
    fflush(stdout);
}

void revenant_log_to(NSString *path)
{
    if (path) {
        NSString *folder = [path stringByDeletingLastPathComponent];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error])
            NSLog(@"revenant_log_to: cannot make %@: %@", folder, error);
        if (freopen(path.fileSystemRepresentation, "w", stdout))
            setvbuf(stdout, NULL, _IOLBF, 0);
    }
    NSSetUncaughtExceptionHandler(revenant_uncaught);
}
