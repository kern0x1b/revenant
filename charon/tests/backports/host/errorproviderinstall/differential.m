#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"
#import "errorprovider-cases.h"
#import "errorprovider-expectations.h"

void charon_install_user_info_value_provider(Class cls);

static int charon_divergences;

static NSSet *divergences(void)
{
    return [NSSet setWithObject:@"description text"];
}

static Class probe_class(const char *name)
{
    Class probe = objc_allocateClassPair([NSError class], name, 0);
    objc_registerClassPair(probe);
    return probe;
}

static NSArray *ordered(NSDictionary *rows)
{
    return [rows.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

static NSDictionary *answers(Class error_class, ErrorProviderSetter set_provider)
{
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    errorprovider_run(error_class, set_provider, ^(NSString *name, NSString *value) {
        records[name] = value;
    });
    return records;
}

static SEL ported_set_provider(void)
{
    return NSSelectorFromString(@"charonHost_setUserInfoValueProviderForDomain:provider:");
}

static void set_provider(SEL selector, Class error_class, NSString *domain, id provider)
{
    ((void (*)(id, SEL, id, id))objc_msgSend)(error_class, selector, domain, provider);
}

int main(void)
{
    @autoreleasepool {
        NSData *recorded_data = [NSData dataWithBytes:errorprovider_expectations length:strlen(errorprovider_expectations)];
        NSDictionary *recorded = [NSJSONSerialization JSONObjectWithData:recorded_data options:0 error:NULL];
        if (!recorded) {
            charon_check(NO, "the recording is readable", @"errorprovider-expectations.h does not hold a JSON object");
            printf("checks=%d failures=%d divergences=%d\n", charon_checks, charon_failures, charon_divergences);
            return charon_failures;
        }

        NSDictionary *host = answers([NSError class], ^(Class error_class, NSString *domain, id provider) {
            [NSError setUserInfoValueProviderForDomain:domain provider:provider];
        });
        for (NSString *name in ordered(recorded)) {
            charon_check([host[name] isEqualToString:recorded[name]],
                         [[NSString stringWithFormat:@"the host answers %@ as it was recorded", name] UTF8String],
                         [NSString stringWithFormat:@"\n    this host    %@\n    recorded    %@", host[name], recorded[name]]);
        }

        SEL set = ported_set_provider();
        Class plain = probe_class("CharonProviderControl");
        NSDictionary *control = answers(plain, ^(Class error_class, NSString *domain, id provider) {
            set_provider(set, error_class, domain, provider);
        });
        Class probe = probe_class("CharonProviderProbe");
        charon_install_user_info_value_provider(probe);
        charon_check([probe instancesRespondToSelector:NSSelectorFromString(@"localizedDescription")] &&
                     class_getMethodImplementation(probe, NSSelectorFromString(@"localizedDescription")) !=
                     class_getMethodImplementation([NSError class], NSSelectorFromString(@"localizedDescription")),
                     "the install put a method of its own on the class",
                     @"the class answers -localizedDescription with the host's own implementation alone");
        NSDictionary *port = answers(probe, ^(Class error_class, NSString *domain, id provider) {
            set_provider(set, error_class, domain, provider);
        });
        for (NSString *name in ordered(recorded)) {
            NSString *detail = [NSString stringWithFormat:@"\n    the port    %@\n    the host    %@", port[name], host[name]];
            if (![divergences() containsObject:name]) {
                charon_check([port[name] isEqualToString:recorded[name]],
                             [[NSString stringWithFormat:@"the port answers %@ as the host does", name] UTF8String], detail);
                continue;
            }
            charon_divergences++;
            printf("note %s: the port answers %s where the host answers %s\n", name.UTF8String,
                   [port[name] UTF8String], [host[name] UTF8String]);
            charon_check([port[name] isEqualToString:control[name]],
                         [[NSString stringWithFormat:@"%@ is this class's own answer, not the install's", name] UTF8String],
                         [NSString stringWithFormat:@"\n    the port        %@\n    the same class without the install    %@", port[name], control[name]]);
            charon_check(![port[name] isEqualToString:host[name]],
                         [[NSString stringWithFormat:@"%@ still differs, so the note is not stale", name] UTF8String], detail);
        }

        NSError *before = [NSError errorWithDomain:@"charon.guard" code:7 userInfo:nil];
        NSString *host_answer = before.localizedDescription;
        set_provider(set, probe, @"charon.guard", ^id(NSError *error, NSErrorUserInfoKey key) {
            return [key isEqualToString:NSLocalizedDescriptionKey] ? @"a description the port's registry holds" : nil;
        });
        NSError *guarded = [probe errorWithDomain:@"charon.guard" code:7 userInfo:nil];
        charon_check([guarded.localizedDescription isEqualToString:@"a description the port's registry holds"],
                     "a provider in the port's registry answers on the class the install was pointed at",
                     [NSString stringWithFormat:@"the class answers %@", guarded.localizedDescription]);
        charon_check([before.localizedDescription isEqualToString:host_answer],
                     "the host's own NSError is not touched by the port's install",
                     [NSString stringWithFormat:@"\n    now         %@\n    before      %@", before.localizedDescription, host_answer]);

        printf("checks=%d failures=%d divergences=%d\n", charon_checks, charon_failures, charon_divergences);
    }
    return charon_failures;
}
