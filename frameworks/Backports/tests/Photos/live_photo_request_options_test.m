#import "../Foundation/check.h"
#import <Photos/Photos.h>

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    PHLivePhotoRequestOptions *options = [[PHLivePhotoRequestOptions alloc] init];
    revenant_check(options.version == PHImageRequestOptionsVersionCurrent, "a new live photo request asks for the current version", @"the version default differs");
    revenant_check(options.deliveryMode == PHImageRequestOptionsDeliveryModeOpportunistic, "a new live photo request is opportunistic", @"the delivery mode default differs");
    revenant_check(!options.networkAccessAllowed, "a new live photo request does not reach the network", @"the network default differs");
    revenant_check(options.progressHandler == nil, "a new live photo request has no progress handler", @"the progress handler default differs");
    revenant_check([options conformsToProtocol:@protocol(NSCopying)], "live photo request options conform to NSCopying", @"the class does not conform to NSCopying");

    options.version = PHImageRequestOptionsVersionUnadjusted;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    options.networkAccessAllowed = YES;
    options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) { };

    PHLivePhotoRequestOptions *copy = [options copy];
    revenant_check(copy != options && [copy class] == [options class], "a copy is a new object of the same class", @"the copy is the original or another class");
    revenant_check(copy.version == PHImageRequestOptionsVersionUnadjusted && copy.deliveryMode == PHImageRequestOptionsDeliveryModeFastFormat && copy.networkAccessAllowed == YES && copy.progressHandler != nil,
                   "a copy keeps every option", @"the copy lost an option");

    copy.version = PHImageRequestOptionsVersionCurrent;
    copy.networkAccessAllowed = NO;
    BOOL kept = options.version == PHImageRequestOptionsVersionUnadjusted && options.networkAccessAllowed == YES;
    revenant_check(revenant_negative ? !kept : kept, "changing a copy leaves the original alone", @"the original changed with its copy");
    return revenant_finish();
}
