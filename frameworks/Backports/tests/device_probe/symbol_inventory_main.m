#import <Foundation/Foundation.h>
#include <dlfcn.h>

static const char *const NAMES[] = {
    "AVVideoColorPrimariesKey",
    "AVVideoColorPrimaries_ITU_R_709_2",
    "AVVideoColorPrimaries_SMPTE_C",
    "AVVideoColorPropertiesKey",
    "AVVideoTransferFunctionKey",
    "AVVideoTransferFunction_ITU_R_709_2",
    "AVVideoYCbCrMatrixKey",
    "AVVideoYCbCrMatrix_ITU_R_601_4",
    "AVVideoYCbCrMatrix_ITU_R_709_2",
    "CTRadioAccessTechnologyCDMA1x",
    "CTRadioAccessTechnologyCDMAEVDORev0",
    "CTRadioAccessTechnologyCDMAEVDORevA",
    "CTRadioAccessTechnologyCDMAEVDORevB",
    "CTRadioAccessTechnologyDidChangeNotification",
    "CTRadioAccessTechnologyEdge",
    "CTRadioAccessTechnologyGPRS",
    "CTRadioAccessTechnologyHSDPA",
    "CTRadioAccessTechnologyHSUPA",
    "CTRadioAccessTechnologyLTE",
    "CTRadioAccessTechnologyeHRPD",
    "MPMediaPlaylistPropertySeedItems",
    "NSProgressFileCompletedCountKey",
    "NSProgressFileOperationKindCopying",
    "NSProgressFileOperationKindDecompressingAfterDownloading",
    "NSProgressFileOperationKindDownloading",
    "NSProgressFileOperationKindKey",
    "NSProgressFileTotalCountKey",
    "NSProgressFileURLKey",
    "NSProgressKindFile",
    "NSProgressThroughputKey",
    "UITableViewAutomaticDimension",
    "kSecAttrSynchronizable",
    "UIContentSizeCategoryLarge",
    "NSFoundationVersionNumber",
    NULL,
};

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSMutableString *log = [NSMutableString string];
        for (const char *const *name = NAMES; *name != NULL; name++) {
            void *address = dlsym(RTLD_DEFAULT, *name);
            [log appendFormat:@"%s %s\n", *name, address ? "exported" : "absent"];
        }
        [log writeToFile:@"/var/revenant/symbol-inventory.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSLog(@"%@", log);
    }
    return 0;
}
