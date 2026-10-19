#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"
#import "wsserver.h"

extern int CharonHostcharon_network_cellular_override;

static uint64_t state = 0x4E7ACCE55ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static BOOL flag(id object, NSString *name, BOOL port)
{
    NSString *selector = port ? [@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]] : name;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(selector));
}

static void set_flag(id object, NSString *name, BOOL value, BOOL port)
{
    NSString *setter = [@"set" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
    if (port)
        setter = [@"charonHostSet" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(object, NSSelectorFromString([setter stringByAppendingString:@":"]), value);
}

static NSString *state_of(NSURLRequest *request, BOOL port)
{
    return [NSString stringWithFormat:@"%d%d", flag(request, @"allowsExpensiveNetworkAccess", port), flag(request, @"allowsConstrainedNetworkAccess", port)];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSURL *URL = [NSURL URLWithString:@"http://example.com/"];
        NSUInteger wrong = 0, cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 3000;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            NSMutableArray *logs = [NSMutableArray array];
            for (int pass = 0; pass < 2; pass++) {
                BOOL port = pass == 0;
                uint64_t saved = state;
                NSMutableString *log = [NSMutableString string];
                NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:URL];
                NSURLRequest *current = mutableRequest;
                [log appendString:state_of(current, port)];
                for (int step = 0; step < 6; step++) {
                    switch (next() % 6) {
                    case 0: set_flag(mutableRequest, @"allowsExpensiveNetworkAccess", next() % 2, port); break;
                    case 1: set_flag(mutableRequest, @"allowsConstrainedNetworkAccess", next() % 2, port); break;
                    case 2: current = [mutableRequest copy]; break;
                    case 3: mutableRequest = [current mutableCopy]; current = mutableRequest; break;
                    case 4: current = [[NSURLRequest alloc] initWithURL:URL]; break;
                    default: current = [mutableRequest mutableCopy]; mutableRequest = (NSMutableURLRequest *)current; break;
                    }
                    [log appendFormat:@" %@|%@", state_of(current, port), state_of(mutableRequest, port)];
                }
                [logs addObject:log];
                state = saved;
            }
            if (![logs[0] isEqualToString:logs[1]]) {
                wrong++;
                if (samples.count < 5)
                    [samples addObject:[NSString stringWithFormat:@"port %@\n     system %@", logs[0], logs[1]]];
            }
            (void)next();
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "requests keep and pass on their network flags through copies as the system's do", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases]);

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        CHECK(flag(configuration, @"allowsExpensiveNetworkAccess", YES) == configuration.allowsExpensiveNetworkAccess && flag(configuration, @"allowsConstrainedNetworkAccess", YES), "a configuration allows both by default");
        set_flag(configuration, @"allowsExpensiveNetworkAccess", NO, YES);
        NSURLSessionConfiguration *copy = [configuration copy];
        CHECK(!flag(configuration, @"allowsExpensiveNetworkAccess", YES) && flag(configuration, @"allowsConstrainedNetworkAccess", YES) && !flag(copy, @"allowsExpensiveNetworkAccess", YES), "a configuration keeps a flag it was given, and its copy has it");

        int listener = wsserver_start();
        NSURL *local = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/plain", listener]];
        NSMutableURLRequest *forbidding = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://192.0.2.1/x"]];
        forbidding.timeoutInterval = 3;
        set_flag(forbidding, @"allowsExpensiveNetworkAccess", NO, YES);
        CharonHostcharon_network_cellular_override = 1;
        NSError *error = nil;
        NSHTTPURLResponse *response = nil;
        NSData *body = [NSURLConnection sendSynchronousRequest:forbidding returningResponse:&response error:&error];
        CHECK(body == nil && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet && [error.userInfo[NSURLErrorNetworkUnavailableReasonKey] integerValue] == NSURLErrorNetworkUnavailableReasonExpensive,
              "a request that forbids expensive networks fails on a cellular path, with the reason of the release that has one");
        NSMutableURLRequest *toLocal = [NSMutableURLRequest requestWithURL:local];
        set_flag(toLocal, @"allowsExpensiveNetworkAccess", NO, YES);
        error = nil;
        body = [NSURLConnection sendSynchronousRequest:toLocal returningResponse:&response error:&error];
        CHECK(body != nil && response.statusCode == 200, "a request to this device is never held back");
        CharonHostcharon_network_cellular_override = 0;
        error = nil;
        body = [NSURLConnection sendSynchronousRequest:toLocal returningResponse:&response error:&error];
        CHECK(body != nil && response.statusCode == 200, "and neither is one on a path that is not cellular");
        NSMutableURLRequest *unbothered = [NSMutableURLRequest requestWithURL:local];
        CharonHostcharon_network_cellular_override = 1;
        error = nil;
        body = [NSURLConnection sendSynchronousRequest:unbothered returningResponse:&response error:&error];
        CHECK(body != nil, "a request that says nothing about it is never held back either");
        CharonHostcharon_network_cellular_override = -1;
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
