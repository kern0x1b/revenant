#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Protocol *taskDelegate = @protocol(NSURLSessionTaskDelegate);
    Protocol *dataDelegate = @protocol(NSURLSessionDataDelegate);
    Protocol *downloadDelegate = @protocol(NSURLSessionDownloadDelegate);
    revenant_check(taskDelegate != NULL, "the task delegate protocol exists", @"missing");
    revenant_check(dataDelegate != NULL, "the data delegate protocol exists", @"missing");
    revenant_check(downloadDelegate != NULL, "the download delegate protocol exists", @"missing");
    BOOL dataConforms = protocol_conformsToProtocol(dataDelegate, taskDelegate);
    revenant_check(dataConforms == (revenant_negative ? NO : YES), "the data delegate conforms to the task delegate", [NSString stringWithFormat:@"%d", dataConforms]);
    BOOL downloadConforms = protocol_conformsToProtocol(downloadDelegate, taskDelegate);
    revenant_check(downloadConforms == YES, "the download delegate conforms to the task delegate", [NSString stringWithFormat:@"%d", downloadConforms]);
    return revenant_finish();
}
