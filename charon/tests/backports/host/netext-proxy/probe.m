#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>

/* One reader, two binaries, the shape the NEDNSSettings slice established: Apple's framework alone on
   the host side, the port's objects with Apple's framework *not linked* on the port side, and a dladdr
   line per class so nothing can be read as the port's answer when Apple's is what answered.

   Every property name of these six classes that the host's own NetworkExtension carries is comparable,
   and the run measures that rather than assuming it: the header oracle is only used for the two names
   the 26.2 header marks API_UNAVAILABLE on every platform, which Apple's class therefore cannot answer.
   The two IPv6 class methods fall into that group, and tests/backports/host/netext-proxy/run.sh checks
   them against this package's own header instead. */
#ifdef HOST_SIDE
#import <NetworkExtension/NetworkExtension.h>
#else
#import "CharonNetworkExtensionSettings.h"
#endif

static void emit(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value ? value : "(nil)");
    fflush(stdout);   /* the harness reads a file, where stdout is fully buffered and a crash would
                          take every line printed so far with it */
}

static void emit_object(const char *name, id value)
{
    emit(name, value ? "an object" : "(nil)");
}

/* An array, with what is in it. "an array" is not an answer a mutation can move: a planted value and
   the value it replaced both print "an array", so every mutation of a collection went unnoticed until
   this printed the count and the elements. */
static void emit_array(const char *name, id value)
{
    if (!value) {
        emit(name, "(nil)");
        return;
    }
    NSArray *array = value;
    NSMutableArray *parts = [NSMutableArray array];
    for (id element in array) {
        /* A value's own text, and for anything else only its class: an object's description carries its
           address, which is different in every process and would make the comparison a comparison of
           addresses. The count and the values are what a mutation of a collection moves. */
        if ([element isKindOfClass:[NSString class]] || [element isKindOfClass:[NSNumber class]]) {
            [parts addObject:[element description]];
        } else {
            [parts addObject:[NSString stringWithFormat:@"a %@", [element class]]];
        }
    }
    emit(name, ([[NSString stringWithFormat:@"%lu:", (unsigned long)array.count] stringByAppendingString:
                 [parts componentsJoinedByString:@","]]).UTF8String);
}

/* A value the caller reads back, as its own text: what a property holds is the answer, and "an object"
   is not it. */
static void emit_value(const char *name, id value)
{
    emit(name, value ? [[value description] UTF8String] : "(nil)");
}

static void emit_bool(const char *name, BOOL value)
{
    emit(name, value ? "YES" : "NO");
}

static void prove(NSString *label, Class cls, SEL selector)
{
    Method m = class_getInstanceMethod(cls, selector);
    IMP imp = m ? method_getImplementation(m) : NULL;
    Dl_info info;
    memset(&info, 0, sizeof info);
    /* The proof, stated plainly: dladdr fills dli_fname or it does not, and either way the answer is
       written down rather than summarised. A method in the dyld shared cache is Apple's, and the path
       it reports is the cache's own - which is the strongest statement this proof can make: the
       implementation is not in this process's image at all. An unresolved one is printed as
       unresolved, and the harness fails on it rather than reading a green verdict out of an empty. */
    const char *where;
    if (!imp) {
        where = "no IMP: the class does not carry the selector in this binary";
    } else if (!dladdr((const void *)imp, &info)) {
        where = "dladdr did not fill it: the implementation is in the dyld shared cache";
    } else if (!info.dli_fname || !*info.dli_fname) {
        where = "dladdr filled no name: the implementation is in the dyld shared cache";
    } else {
        where = info.dli_fname;
    }
    printf("%s.dladdr\t%s\n", [label UTF8String], where);
    fflush(stdout);
}

int main(void)
{
    @autoreleasepool {
        Class server = NSClassFromString(@"NEProxyServer");
        Class settings = NSClassFromString(@"NEProxySettings");
        Class v4 = NSClassFromString(@"NEIPv4Settings");
        Class route = NSClassFromString(@"NEIPv4Route");
        Class v6 = NSClassFromString(@"NEIPv6Settings");
        Class route6 = NSClassFromString(@"NEIPv6Route");
        printf("classes\t%s%s%s%s%s%s\n",
               server ? "NEProxyServer " : "", settings ? "NEProxySettings " : "",
               v4 ? "NEIPv4Settings " : "", route ? "NEIPv4Route " : "",
               v6 ? "NEIPv6Settings " : "", route6 ? "NEIPv6Route" : "");
        fflush(stdout);
        if (!server || !settings || !v4 || !route || !v6 || !route6)
            return 1;

        prove(@"NEProxyServer", server, @selector(address));
        prove(@"NEProxySettings", settings, @selector(exceptionList));
        prove(@"NEIPv4Settings", v4, @selector(addresses));
        prove(@"NEIPv4Route", route, @selector(destinationAddress));
        prove(@"NEIPv6Settings", v6, @selector(addresses));
        prove(@"NEIPv6Route", route6, @selector(destinationAddress));

        id filledServer = [[server alloc] init];
        [filledServer setValue:@[@"planted-user"] forKey:@"username"];
        [filledServer setValue:@[@"planted-pass"] forKey:@"password"];
        [filledServer setValue:@YES forKey:@"authenticationRequired"];
        emit_value("serverRoundTrip.username", [filledServer valueForKey:@"username"]);
        emit_value("serverRoundTrip.password", [filledServer valueForKey:@"password"]);
        emit_bool("serverRoundTrip.authenticationRequired", [[filledServer valueForKey:@"authenticationRequired"] boolValue]);

        id freshServer = [[server alloc] init];
        emit_object("NEProxyServer.username", [freshServer valueForKey:@"username"]);
        emit_object("NEProxyServer.password", [freshServer valueForKey:@"password"]);
        emit_bool("NEProxyServer.authenticationRequired", [[freshServer valueForKey:@"authenticationRequired"] boolValue]);

        id freshSettings = [[settings alloc] init];
        emit_bool("NEProxySettings.autoProxyConfigurationEnabled", [[freshSettings valueForKey:@"autoProxyConfigurationEnabled"] boolValue]);
        emit_object("NEProxySettings.proxyAutoConfigurationURL", [freshSettings valueForKey:@"proxyAutoConfigurationURL"]);
        emit_object("NEProxySettings.proxyAutoConfigurationJavaScript", [freshSettings valueForKey:@"proxyAutoConfigurationJavaScript"]);
        emit_bool("NEProxySettings.HTTPEnabled", [[freshSettings valueForKey:@"HTTPEnabled"] boolValue]);
        emit_object("NEProxySettings.HTTPServer", [freshSettings valueForKey:@"HTTPServer"]);
        emit_bool("NEProxySettings.HTTPSEnabled", [[freshSettings valueForKey:@"HTTPSEnabled"] boolValue]);
        emit_object("NEProxySettings.HTTPSServer", [freshSettings valueForKey:@"HTTPSServer"]);
        emit_bool("NEProxySettings.excludeSimpleHostnames", [[freshSettings valueForKey:@"excludeSimpleHostnames"] boolValue]);
        emit_array("NEProxySettings.exceptionList", [freshSettings valueForKey:@"exceptionList"]);
        emit_array("NEProxySettings.matchDomains", [freshSettings valueForKey:@"matchDomains"]);

        id freshV4 = [[v4 alloc] init];
        emit_array("NEIPv4Settings.addresses", [freshV4 valueForKey:@"addresses"]);
        emit_array("NEIPv4Settings.subnetMasks", [freshV4 valueForKey:@"subnetMasks"]);
        emit_object("NEIPv4Settings.router", [freshV4 valueForKey:@"router"]);
        emit_array("NEIPv4Settings.includedRoutes", [freshV4 valueForKey:@"includedRoutes"]);
        emit_array("NEIPv4Settings.excludedRoutes", [freshV4 valueForKey:@"excludedRoutes"]);

        id freshRoute = [[route alloc] init];
        emit_object("NEIPv4Route.destinationAddress", [freshRoute valueForKey:@"destinationAddress"]);
        emit_object("NEIPv4Route.destinationSubnetMask", [freshRoute valueForKey:@"destinationSubnetMask"]);
        emit_object("NEIPv4Route.gatewayAddress", [freshRoute valueForKey:@"gatewayAddress"]);

        id freshV6 = [[v6 alloc] init];
        emit_array("NEIPv6Settings.addresses", [freshV6 valueForKey:@"addresses"]);
        emit_array("NEIPv6Settings.networkPrefixLengths", [freshV6 valueForKey:@"networkPrefixLengths"]);
        emit_array("NEIPv6Settings.includedRoutes", [freshV6 valueForKey:@"includedRoutes"]);
        emit_array("NEIPv6Settings.excludedRoutes", [freshV6 valueForKey:@"excludedRoutes"]);

        id freshRoute6 = [[route6 alloc] init];
        emit_object("NEIPv6Route.destinationAddress", [freshRoute6 valueForKey:@"destinationAddress"]);
        emit_value("NEIPv6Route.destinationNetworkPrefixLength", [freshRoute6 valueForKey:@"destinationNetworkPrefixLength"]);
        emit_object("NEIPv6Route.gatewayAddress", [freshRoute6 valueForKey:@"gatewayAddress"]);

        /* the IPv6 default route, which is a fixed answer and the one place the port guessed: the header
           only says "the route that matches everything", and the host says what its own object is */
        id default6 = [route6 performSelector:@selector(defaultRoute)];
        emit_value("NEIPv6Route.defaultRoute.destinationAddress", [default6 valueForKey:@"destinationAddress"]);
        emit_value("NEIPv6Route.defaultRoute.prefixLength", [default6 valueForKey:@"destinationNetworkPrefixLength"]);
        emit_object("NEIPv6Route.defaultRoute.gatewayAddress", [default6 valueForKey:@"gatewayAddress"]);

        /* the two class methods the 26.2 header marks API_UNAVAILABLE everywhere: Apple's class does not
           answer them, so what is checked is that the port's objects do, and that they answer the empty
           arrays their read-only properties answer */
        id automatic = [v6 performSelector:@selector(settingsWithAutomaticAddressing)];
        id linkLocal = [v6 performSelector:@selector(settingsWithLinkLocalAddressing)];
        emit_object("NEIPv6Settings.settingsWithAutomaticAddressing", automatic);
        emit_array("NEIPv6Settings.automatic.addresses", [automatic valueForKey:@"addresses"]);
        emit_array("NEIPv6Settings.automatic.networkPrefixLengths", [automatic valueForKey:@"networkPrefixLengths"]);
        emit_object("NEIPv6Settings.settingsWithLinkLocalAddressing", linkLocal);
        emit_array("NEIPv6Settings.linkLocal.addresses", [linkLocal valueForKey:@"addresses"]);

        /* and the answers a caller can change, which is what makes them state rather than a constant */
        NEProxySettings *filled = [[NEProxySettings alloc] init];
        [filled setHTTPEnabled:YES];
        [filled setExceptionList:@[@"example.com"]];
        /* the value, not the pointer: `? YES : NO` on an NSNumber is a test of whether it is there, and
           that made this line print YES for a NO, which is how the mutation that inverts the setter went
           unnoticed */
        emit_bool("roundTrip.HTTPEnabled", [[filled valueForKey:@"HTTPEnabled"] boolValue] ? YES : NO);
        [filled setValue:@[@"planted.example"] forKey:@"matchDomains"];
        emit_array("roundTrip.matchDomains", [filled valueForKey:@"matchDomains"]);
        emit_array("roundTrip.exceptionList", [filled valueForKey:@"exceptionList"]);
        emit_bool("copy.isSameObject", [filled copy] == filled ? YES : NO);
        NSError *error = nil;
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:filled requiringSecureCoding:YES error:&error];
        emit("archive.hasData", archived ? "YES" : "NO");
        emit("archive.errorDomain", error ? [error.domain UTF8String] : "(none)");

        NEIPv6Settings *filled6 = [[NEIPv6Settings alloc] init];
        [filled6 setIncludedRoutes:@[[[NEIPv6Route alloc] initWithDestinationAddress:@"2001:db8::"
                                                                    networkPrefixLength:@32]]];
        emit_array("v6RoundTrip.includedRoutes", [filled6 valueForKey:@"includedRoutes"]);
        emit_value("v6RoundTrip.route.destination", [[[filled6 valueForKey:@"includedRoutes"] objectAtIndex:0]
                                                        valueForKey:@"destinationAddress"]);
        emit_value("v6RoundTrip.route.prefix", [[[filled6 valueForKey:@"includedRoutes"] objectAtIndex:0]
                                                   valueForKey:@"destinationNetworkPrefixLength"]);
        emit_bool("v6Copy.isSameObject", [filled6 copy] == filled6 ? YES : NO);
        NSError *error6 = nil;
        NSData *archived6 = [NSKeyedArchiver archivedDataWithRootObject:filled6 requiringSecureCoding:YES error:&error6];
        emit("v6Archive.hasData", archived6 ? "YES" : "NO");
        emit("v6Archive.errorDomain", error6 ? [error6.domain UTF8String] : "(none)");
    }
    return 0;
}
