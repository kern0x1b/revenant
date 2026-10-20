#import "RevPrefs.h"
#import <stdlib.h>
#import <string.h>
#import <signal.h>
#import <sys/sysctl.h>

static NSString *const kRevDomain = @"space.kern0x1b.rev";

@interface RevRootListController : PSListController
@end

@implementation RevRootListController

- (id)readPreferenceValue:(PSSpecifier *)spec {
    NSString *domain = [spec propertyForKey:@"defaults"] ?: kRevDomain;
    NSString *key = [spec propertyForKey:@"key"];
    CFPreferencesAppSynchronize((CFStringRef)domain);
    CFPropertyListRef v = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)domain);
    id value = [(id)v autorelease];
    return value ?: [spec propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)spec {
    NSString *domain = [spec propertyForKey:@"defaults"] ?: kRevDomain;
    NSString *key = [spec propertyForKey:@"key"];
    CFPreferencesSetAppValue((CFStringRef)key, (CFTypeRef)value, (CFStringRef)domain);
    CFPreferencesAppSynchronize((CFStringRef)domain);
    if ([key isEqualToString:@"NewTabStartPage"] || [key isEqualToString:@"CustomURLEnabled"]) {
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

- (BOOL)revBool:(NSString *)key default:(BOOL)def {
    CFPreferencesAppSynchronize((CFStringRef)kRevDomain);
    CFPropertyListRef v = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)kRevDomain);
    id value = [(id)v autorelease];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : def;
}

- (NSArray *)specifiers {
    if (_specifiers)
        return _specifiers;
    NSMutableArray *loaded = [self loadSpecifiersFromPlistName:@"Root" target:self];
    BOOL startOn = [self revBool:@"NewTabStartPage" default:YES];
    BOOL customOn = [self revBool:@"CustomURLEnabled" default:NO];
    NSMutableArray *out = [NSMutableArray array];
    for (PSSpecifier *sp in loaded) {
        NSString *sid = [sp identifier];
        if (!startOn && ([sid isEqualToString:@"customGroup"] || [sid isEqualToString:@"CustomURLEnabled"] || [sid isEqualToString:@"CustomURL"]))
            continue;
        if (startOn && !customOn && [sid isEqualToString:@"CustomURL"])
            continue;
        [out addObject:sp];
    }
    _specifiers = [out copy];
    return _specifiers;
}

- (void)respring {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0 || size == 0)
        return;
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (!procs)
        return;
    if (sysctl(mib, 4, procs, &size, NULL, 0) == 0) {
        int count = (int)(size / sizeof(struct kinfo_proc));
        for (int i = 0; i < count; i++) {
            if (strcmp(procs[i].kp_proc.p_comm, "SpringBoard") == 0)
                kill(procs[i].kp_proc.p_pid, SIGKILL);
        }
    }
    free(procs);
}

@end
