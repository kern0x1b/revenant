#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <DeviceCheck/DeviceCheck.h>
#import "check.h"

// The port's DCAppAttestService against the host's own DeviceCheck. The host is a platform that does
// not provide the App Attest service, and an iPhone 4S and an iPad 2 are two more: no Secure Enclave,
// which came with the A7 of the iPhone 5s. So every question here is one the port must answer as the
// host does: not supported, no key, and the documented error, off the main thread and after the call.

@interface CharonHostDCAppAttestService : NSObject
+ (DCAppAttestService *)sharedService;
- (BOOL)isSupported;
- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId, NSError *error))completionHandler;
- (void)attestKey:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *object, NSError *error))completionHandler;
- (void)generateAssertion:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *object, NSError *error))completionHandler;
@end

// sharedService is a class method on both sides; a protocol says so without naming either class, so
// the port's renamed class and the system's are asked the same way.
@protocol Shared <NSObject>
+ (id)sharedService;
@end

@interface Answer : NSObject
@property (nonatomic) BOOL present;
@property (nonatomic) unsigned long code;
@property (nonatomic) int on_main;
@property (nonatomic) int after_return;
@end

@implementation Answer
@end

static NSString *const KeyId = @"ABCD0123-4567-89AB-CDEF-0123456789AB";

// Records what a completion heard and whether it had already returned when it did.
static Answer *record(Answer *answer, BOOL present, NSError *error, int returned)
{
    answer.present = present;
    answer.code = error ? (unsigned long)error.code : 0;
    answer.on_main = [NSThread isMainThread] ? 1 : 0;
    answer.after_return = returned;
    return answer;
}

static void spin(Answer *answer, volatile int *done)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while (!*done && [limit timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    if (!*done) {
        // A call that never answers is not an answer: the checks below read it as a failure.
        record(answer, YES, [NSError errorWithDomain:DCErrorDomain code:999 userInfo:nil], 0);
    }
}

#define ANSWER_BODY  Answer *answer = [[Answer alloc] init]; __block volatile int done = 0; int returned = 0;
#define ANSWER_END(returned_value, error_value)  record(answer, (returned_value), (error_value), returned)

static Answer *ask_port_key(id service)
{
    ANSWER_BODY
    [service generateKeyWithCompletionHandler:^(NSString *keyId, NSError *error) {
        ANSWER_END(keyId != nil, error);
        done = 1;
    }];
    returned = 1;
    spin(answer, &done);
    return answer;
}

static Answer *ask_host_key(id service)
{
    ANSWER_BODY
    [(DCAppAttestService *)service generateKeyWithCompletionHandler:^(NSString *keyId, NSError *error) {
        ANSWER_END(keyId != nil, error);
        done = 1;
    }];
    returned = 1;
    spin(answer, &done);
    return answer;
}

#define ATTEST_BODY(OWNER, NAME)                                                                                            \
    ANSWER_BODY                                                                                                             \
    NSData *hash = [NSMutableData dataWithLength:32];                                                                        \
    [OWNER NAME:KeyId clientDataHash:hash completionHandler:^(NSData *object, NSError *error) {                              \
        ANSWER_END(object != nil, error);                                                                                   \
        done = 1;                                                                                                           \
    }];                                                                                                                     \
    returned = 1;                                                                                                           \
    spin(answer, &done);                                                                                                    \
    return answer;

static Answer *ask_port_attest(id service)
{
    ATTEST_BODY(service, attestKey)
}

static Answer *ask_host_attest(id service)
{
    ATTEST_BODY(service, attestKey)
}

static Answer *ask_port_assertion(id service)
{
    ATTEST_BODY(service, generateAssertion)
}

static Answer *ask_host_assertion(id service)
{
    ATTEST_BODY(service, generateAssertion)
}

static NSString *describe(Answer *answer)
{
    return [NSString stringWithFormat:@"%@, code %lu, on main %d, after the call %d",
            answer.code == 999 ? @"no answer" : (answer.present ? @"a value" : @"nil"), answer.code, answer.on_main, answer.after_return];
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    Class port_class = NSClassFromString(@"CharonHostDCAppAttestService");
    Class system_class = NSClassFromString(@"DCAppAttestService");
    charon_check(port_class != Nil && system_class != Nil, "both classes are there to ask",
                 [NSString stringWithFormat:@"port %@, host %@", port_class, system_class]);

    id<Shared> port_name = (id<Shared>)port_class;
    id<Shared> system_name = (id<Shared>)system_class;
    id port = [port_name sharedService];
    id host = [system_name sharedService];
    charon_check(port != nil && host != nil, "both hand out a service", @"one of them is nil");
    charon_check([port_name sharedService] == port, "the port's service is one object, asked twice",
                 [NSString stringWithFormat:@"%@", [port_name sharedService]]);
    charon_check([system_name sharedService] == host, "and so is the host's, which is the control",
                 [NSString stringWithFormat:@"%@", [system_name sharedService]]);

    // The host has no +isSupported but does answer -isSupported, the getter the header gives the
    // property; the port is asked the same question.
    BOOL (*send)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    BOOL port_supported = send(port, NSSelectorFromString(@"isSupported"));
    BOOL host_supported = send(host, NSSelectorFromString(@"isSupported"));
    charon_check(port_supported == host_supported, "the answer to isSupported is the host's",
                 [NSString stringWithFormat:@"port %d, host %d", (int)port_supported, (int)host_supported]);
    charon_check(port_supported == NO, "and it is NO, a device that does not provide the service",
                 [NSString stringWithFormat:@"port %d", (int)port_supported]);

    Answer *port_key = ask_port_key(port);
    Answer *host_key = ask_host_key(host);
    charon_check(port_key.code == host_key.code, "a key is not made, with the code the host gives",
                 [NSString stringWithFormat:@"port %@, host %@", describe(port_key), describe(host_key)]);
    charon_check(port_key.code == DCErrorFeatureUnsupported, "the code is the one the header defines as the feature being unavailable",
                 [NSString stringWithFormat:@"port %lu", port_key.code]);

    Answer *port_attest = ask_port_attest(port);
    Answer *host_attest = ask_host_attest(host);
    charon_check(port_attest.code == host_attest.code, "nothing is attested, with the code the host gives",
                 [NSString stringWithFormat:@"port %@, host %@", describe(port_attest), describe(host_attest)]);
    charon_check(port_attest.code == DCErrorInvalidInput, "which is DCErrorInvalidInput for a key no device made",
                 [NSString stringWithFormat:@"port %lu", port_attest.code]);

    Answer *port_assertion = ask_port_assertion(port);
    Answer *host_assertion = ask_host_assertion(host);
    charon_check(port_assertion.code == host_assertion.code, "nothing is signed, with the code the host gives",
                 [NSString stringWithFormat:@"port %@, host %@", describe(port_assertion), describe(host_assertion)]);
    charon_check(port_assertion.code == DCErrorInvalidInput, "which is DCErrorInvalidInput as well",
                 [NSString stringWithFormat:@"port %lu", port_assertion.code]);

    [port generateKeyWithCompletionHandler:nil];
    [port attestKey:KeyId clientDataHash:[NSMutableData dataWithLength:32] completionHandler:nil];
    [port generateAssertion:KeyId clientDataHash:[NSMutableData dataWithLength:32] completionHandler:nil];
    charon_check(YES, "a nil completion handler is ignored by all three", @"raised");

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
