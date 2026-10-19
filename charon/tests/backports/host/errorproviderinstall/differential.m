#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"
#import "errorprovider-cases.h"
#import "errorprovider-expectations.h"

/* The port's own install of the user info value provider, against this Mac's NSError, over the nineteen
   cases tests/backports/device/errorprovider.m asks on a device with the library loaded.

   Two sides in one process, and the oracle is this host's own Foundation. NSError itself with the provider
   registered in the host's own registry is what tests/backports/host/errorprovider/run.sh recorded into
   errorprovider-expectations.h; the first set of checks asks those same nineteen questions again and
   compares them with the recording, so a row that fails below is the port and not a recording that has
   drifted. The port is a class of this test's own - a subclass of NSError, so the errors it makes are of
   that class - with the port's install pointed at it and the provider registered in the port's own
   registry under the spelling prefix_selectors.py gave the port's file.

   Why a class of its own, and not NSError: the provider API arrived in iOS 9.0 and this Foundation has
   carried it since macOS 10.11, so +[CharonErrorProviderInstaller load] returns here without touching
   anything, exactly as it does on every release from 9.0 on. The install is what the six methods need on
   the releases before, so it is what is measured here: pointed at a class it does not own, the release's
   own implementation of each method is the fallback it keeps. */

void charon_install_user_info_value_provider(Class cls);

/* One row of the nineteen is a property of the class the errors are made with and not of the six methods the
   port installs, and what is measured is exactly that: on this host -[NSError description] does not follow
   the methods a subclass installs, so the class under the install and the same class with no install both
   answer "Error Domain=charon.provider Code=7 \"(null)\"" where NSError itself answers the provider's text.
   Which implementation reads the third of that format is not something this test can say, and it is not
   claimed here; what the two checks below hold is that the port's answer on that row is the class's own and
   not the install's, and that it still differs from the host's, so the note cannot go stale. Every other row
   is compared. */
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

/* The port's own registry, which only the port's file writes. The class methods of a category are renamed
   like the rest of what the file defines, so the registration cannot be spelled as a message send. */
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

        /* The oracle, asked again: NSError with the provider in the host's own registry. */
        NSDictionary *host = answers([NSError class], ^(Class error_class, NSString *domain, id provider) {
            [NSError setUserInfoValueProviderForDomain:domain provider:provider];
        });
        for (NSString *name in ordered(recorded)) {
            charon_check([host[name] isEqualToString:recorded[name]],
                         [[NSString stringWithFormat:@"the host answers %@ as it was recorded", name] UTF8String],
                         [NSString stringWithFormat:@"\n    this host    %@\n    recorded    %@", host[name], recorded[name]]);
        }

        /* The port: its install on a class of its own, its registry for the provider. */
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
            /* Written down, and asserted both ways: the port answers what this class answers without the
               install, and that is not what the host's class answers. Were the install the difference, the
               port's answer would be the host's, and this check would fail. */
            charon_divergences++;
            printf("note %s: the port answers %s where the host answers %s\n", name.UTF8String,
                   [port[name] UTF8String], [host[name] UTF8String]);
            charon_check([port[name] isEqualToString:control[name]],
                         [[NSString stringWithFormat:@"%@ is this class's own answer, not the install's", name] UTF8String],
                         [NSString stringWithFormat:@"\n    the port        %@\n    the same class without the install    %@", port[name], control[name]]);
            charon_check(![port[name] isEqualToString:host[name]],
                         [[NSString stringWithFormat:@"%@ still differs, so the note is not stale", name] UTF8String], detail);
        }

        /* +load decides on the release alone, so on this Foundation it has left NSError alone: a provider
           in the port's registry for a domain of its own must reach the class the install was pointed at and
           nothing else. The host's answer for the domain is asked first, so the comparison is a reading and
           not the absence of a string. */
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