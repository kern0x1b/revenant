#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_expect_string("NSProgressThroughputKey", NSProgressThroughputKey, @"NSProgressThroughputKey");
    revenant_expect_string("NSProgressKindFile", NSProgressKindFile, revenant_negative ? @"NSProgressKindFileNegative" : @"NSProgressKindFile");
    revenant_expect_string("NSProgressFileOperationKindKey", NSProgressFileOperationKindKey, @"NSProgressFileOperationKindKey");
    revenant_expect_string("NSProgressFileOperationKindDownloading", NSProgressFileOperationKindDownloading, @"NSProgressFileOperationKindDownloading");
    revenant_expect_string("NSProgressFileOperationKindDecompressingAfterDownloading", NSProgressFileOperationKindDecompressingAfterDownloading, @"NSProgressFileOperationKindDecompressingAfterDownloading");
    revenant_expect_string("NSProgressFileOperationKindCopying", NSProgressFileOperationKindCopying, @"NSProgressFileOperationKindCopying");
    revenant_expect_string("NSProgressFileURLKey", NSProgressFileURLKey, @"NSProgressFileURLKey");
    revenant_expect_string("NSProgressFileTotalCountKey", NSProgressFileTotalCountKey, @"NSProgressFileTotalCountKey");
    revenant_expect_string("NSProgressFileCompletedCountKey", NSProgressFileCompletedCountKey, @"NSProgressFileCompletedCountKey");
    return revenant_finish();
}
