#import "check.h"
#import "RevenantOSLog.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    struct os_log_s *defaultLog = (__bridge struct os_log_s *)OS_LOG_DEFAULT;
    BOOL isRevenantLog = defaultLog->isa == [RevenantOSLog class];
    revenant_check(revenant_negative ? !isRevenantLog : isRevenantLog,
                   "OS_LOG_DEFAULT is a real log object of the RevenantOSLog class", @"OS_LOG_DEFAULT is not a RevenantOSLog object");
    revenant_check(defaultLog == &_os_log_default, "OS_LOG_DEFAULT addresses the backport's default object", @"OS_LOG_DEFAULT addresses another object");
    return revenant_finish();
}
