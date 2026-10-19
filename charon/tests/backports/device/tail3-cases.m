#import "tail3-cases.h"

void tail3_run(Tail3Recorder record)
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    record(@"shared container of a default configuration", [NSString stringWithFormat:@"%@", configuration.sharedContainerIdentifier]);
    configuration.sharedContainerIdentifier = @"group.charon.test";
    record(@"shared container set", configuration.sharedContainerIdentifier);
    NSURLSessionConfiguration *copy = [configuration copy];
    record(@"shared container copied", copy.sharedContainerIdentifier);
    copy.sharedContainerIdentifier = @"group.charon.other";
    record(@"copy is independent", [NSString stringWithFormat:@"%@ %@", configuration.sharedContainerIdentifier, copy.sharedContainerIdentifier]);
    NSURLSessionConfiguration *background = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"charon.background"];
    background.sharedContainerIdentifier = @"group.charon.test";
    record(@"background configuration", [NSString stringWithFormat:@"%@ %@", background.identifier, background.sharedContainerIdentifier]);
    configuration.sharedContainerIdentifier = nil;
    record(@"shared container cleared", [NSString stringWithFormat:@"%@", configuration.sharedContainerIdentifier]);
    NSURLSessionConfiguration *mutable = [configuration mutableCopy];
    record(@"mutable copy of a cleared one", [NSString stringWithFormat:@"%@", mutable.sharedContainerIdentifier]);
    NSURLSessionConfiguration *backCopy = [background copy];
    record(@"background copied", backCopy.sharedContainerIdentifier);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:background];
    record(@"session keeps its configuration", [NSString stringWithFormat:@"%d", [session.configuration.sharedContainerIdentifier isEqualToString:@"group.charon.test"]]);
    [session invalidateAndCancel];
}
