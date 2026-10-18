#import "check.h"

int charon_failures;
int charon_checks;

void charon_check(BOOL passed, const char *name, NSString *detail)
{
    charon_checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        charon_failures++;
        printf("FAIL %s: %s\n", name, detail.UTF8String);
    }
    fflush(stdout);
}

static void charon_uncaught(NSException *exception)
{
    printf("FAIL uncaught %s: %s\n%s\n", exception.name.UTF8String, exception.reason.UTF8String, [exception.callStackReturnAddresses description].UTF8String);
    fflush(stdout);
}

void charon_log_to(NSString *path)
{
    // A fresh guest has no folder for the log (no /private/var/backports on the 6.1.3 emulator root), and freopen into a missing
    // folder fails and closes stdout: every line the program printed after it was lost. The folder is made here, as the log is
    // written, so the log lands wherever the program names it.
    if (path) {
        NSString *folder = [path stringByDeletingLastPathComponent];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error])
            NSLog(@"charon_log_to: cannot make %@: %@", folder, error);
        if (freopen(path.fileSystemRepresentation, "w", stdout))
            setvbuf(stdout, NULL, _IOLBF, 0);
    }
    NSSetUncaughtExceptionHandler(charon_uncaught);
}
