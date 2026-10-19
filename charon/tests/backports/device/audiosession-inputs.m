#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *error = nil;
        CHECK([session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error] && [session setActive:YES error:&error], "a record session starts");
        NSArray *inputs = session.availableInputs;
        NSArray *routed = session.currentRoute.inputs;
        CHECK(inputs != nil && inputs.count == routed.count, "the available inputs are the inputs of the current route");
        CHECK(session.preferredInput == nil, "no input is preferred to begin with");
        CHECK([session setPreferredInput:nil error:&error], "clearing the preference succeeds");
        if (inputs.count) {
            AVAudioSessionPortDescription *input = inputs.firstObject;
            CHECK([session setPreferredInput:input error:&error], "preferring the input in use succeeds");
            CHECK([session.preferredInput.UID isEqualToString:input.UID], "and it is the preferred input");
            CHECK([session setPreferredInput:nil error:&error] && session.preferredInput == nil, "and clearing it clears it");
        }
        AVAudioSessionPortDescription *stranger = [[AVAudioSessionPortDescription alloc] init];
        NSError *refused = nil;
        BOOL taken = [session setPreferredInput:stranger error:&refused];
        CHECK(!taken && refused != nil, "an input that is not in the route is refused with an error");
        CHECK_EQUAL(refused.domain, NSOSStatusErrorDomain, "in the domain of OS status codes");
        CHECK(refused.code == AVAudioSessionErrorCodeResourceNotAvailable, "with the code of a resource that is not there");
        CHECK(session.preferredInput == nil, "and nothing is preferred");
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
