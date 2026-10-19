#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import "check.h"

extern const mach_port_t revenantHost_kIOMainPortDefault;
extern kern_return_t revenantHost_IOMainPort(mach_port_t bootstrapPort, mach_port_t *mainPort);
extern io_registry_entry_t revenantHost_IORegistryEntryCopyFromPath(mach_port_t mainPort, CFStringRef path);
extern CFStringRef revenantHost_IORegistryEntryCopyPath(io_registry_entry_t entry, const io_name_t plane);

static NSString *text(CFStringRef string)
{
    return string ? (__bridge NSString *)string : @"(nil)";
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    revenant_check(revenantHost_kIOMainPortDefault == kIOMainPortDefault, "the default main port is the host's",
                 [NSString stringWithFormat:@"port %u, host %u", revenantHost_kIOMainPortDefault, kIOMainPortDefault]);
    revenant_check(revenantHost_kIOMainPortDefault == MACH_PORT_NULL, "and it is MACH_PORT_NULL, the synonym for NULL the header names",
                 [NSString stringWithFormat:@"port %u", revenantHost_kIOMainPortDefault]);

    mach_port_t port_main = 0xdead, host_main = 0xdead;
    kern_return_t port_kr = revenantHost_IOMainPort(MACH_PORT_NULL, &port_main);
    kern_return_t host_kr = IOMainPort(MACH_PORT_NULL, &host_main);
    revenant_check(port_kr == KERN_SUCCESS, "the port's IOMainPort succeeds", [NSString stringWithFormat:@"kr %d", port_kr]);
    revenant_check(port_kr == host_kr, "with the kern_return_t the host gives", [NSString stringWithFormat:@"port %d, host %d", port_kr, host_kr]);
    revenant_check(port_main == revenantHost_kIOMainPortDefault, "and hands back the default main port",
                 [NSString stringWithFormat:@"port %u", port_main]);
    revenant_check(host_main != MACH_PORT_NULL, "the host, on the other hand, has a main port of its own",
                 [NSString stringWithFormat:@"host %u", host_main]);
    revenant_check(revenantHost_IOMainPort(MACH_PORT_NULL, NULL) == KERN_INVALID_ARGUMENT,
                 "a NULL out-parameter is answered KERN_INVALID_ARGUMENT, where the host reads through it and crashes",
                 @"the port read through a NULL out-parameter");

    io_registry_entry_t from_port = revenantHost_IORegistryEntryCopyFromPath(revenantHost_kIOMainPortDefault, CFSTR("IOService:/"));
    io_registry_entry_t from_host = IORegistryEntryCopyFromPath(kIOMainPortDefault, CFSTR("IOService:/"));
    revenant_check((from_port != MACH_PORT_NULL) == (from_host != MACH_PORT_NULL), "a path the host finds, the port finds",
                 [NSString stringWithFormat:@"port %u, host %u", from_port, from_host]);
    if (from_port) IOObjectRelease(from_port);
    if (from_host) IOObjectRelease(from_host);

    NSArray *absent = @[@"NoSuchPlane:/nope", @"garbage", @""];
    for (NSString *path in absent) {
        io_registry_entry_t miss_port = revenantHost_IORegistryEntryCopyFromPath(revenantHost_kIOMainPortDefault, (__bridge CFStringRef)path);
        io_registry_entry_t miss_host = IORegistryEntryCopyFromPath(kIOMainPortDefault, (__bridge CFStringRef)path);
        revenant_check(miss_port == MACH_PORT_NULL, "the port answers MACH_PORT_NULL for a path no entry has",
                     [NSString stringWithFormat:@"port %u for %@", miss_port, path]);
        revenant_check(miss_port == miss_host, "which is what the host answers for the same path",
                     [NSString stringWithFormat:@"port %u, host %u for %@", miss_port, miss_host, path]);
        if (miss_port) IOObjectRelease(miss_port);
        if (miss_host) IOObjectRelease(miss_host);
    }
    revenant_check(revenantHost_IORegistryEntryCopyFromPath(revenantHost_kIOMainPortDefault, NULL) == MACH_PORT_NULL,
                 "a nil path is answered MACH_PORT_NULL, where the host reads through it and crashes",
                 @"the port read through a nil path");

    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    revenant_check(root != 0, "the host's root entry is there to ask about", @"no root entry");
    revenant_check(revenantHost_IORegistryEntryCopyPath(0, kIOServicePlane) == NULL, "an entry of 0 is answered NULL, as the host answers it",
                 @"the port answered something for entry 0");
    CFStringRef root_path = IORegistryEntryCopyPath(root, kIOServicePlane);
    CFStringRef port_root_path = revenantHost_IORegistryEntryCopyPath(root, kIOServicePlane);
    revenant_check((port_root_path == NULL) == (root_path == NULL), "a path the host cannot give, the port cannot give either",
                 [NSString stringWithFormat:@"port %@, host %@", text(port_root_path), text(root_path)]);
    revenant_check([text(port_root_path) isEqualToString:text(root_path)], "and both say the same thing",
                 [NSString stringWithFormat:@"port %@, host %@", text(port_root_path), text(root_path)]);
    if (root_path) CFRelease(root_path);
    if (port_root_path) CFRelease(port_root_path);

    io_string_t buffer;
    kern_return_t get = IORegistryEntryGetPath(root, kIOServicePlane, buffer);
    revenant_check(get != KERN_SUCCESS, "the host's own IORegistryEntryGetPath fails for that entry, which is why the path is nil",
                 [NSString stringWithFormat:@"kr %d", get]);

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
