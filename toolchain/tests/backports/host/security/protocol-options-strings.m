#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>
#import <string.h>

@interface RevenantSecProtocolStrings : NSObject <OS_sec_protocol_options>
- (const char *)revenantServerName;
- (const char *)revenantApplicationProtocolAt:(size_t)index;
- (size_t)revenantApplicationProtocolCount;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}
static int serverNameSurvived = 0, alpnSurvived = 0;

static void setFromAStackFrameThatReturns(sec_protocol_options_t options)
{
    char name[32];
    char alpn[32];
    strcpy(name, "example.invalid");
    strcpy(alpn, "h2");
    sec_protocol_options_set_tls_server_name(options, name);
    sec_protocol_options_add_tls_application_protocol(options, alpn);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"RevenantSecProtocolStrings");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        setFromAStackFrameThatReturns(o);
        const char *heldName = [(id)o revenantServerName];
        if (heldName && strcmp(heldName, "example.invalid") == 0)
            serverNameSurvived = 1;
        const char *heldAlpn = [(id)o revenantApplicationProtocolAt:0];
        if (heldAlpn && strcmp(heldAlpn, "h2") == 0)
            alpnSurvived = 1;
        want("server-name-survives-dead-frame", serverNameSurvived, 1);
        want("alpn-survives-dead-frame", alpnSurvived, 1);

        sec_protocol_options_add_tls_application_protocol(o, "http/1.1");
        sec_protocol_options_add_tls_application_protocol(o, "spdy/2");
        want("alpn-count", (long)[(id)o revenantApplicationProtocolCount], 3);
        printf("alpn-0\t%s\n", [(id)o revenantApplicationProtocolAt:0]);
        printf("alpn-1\t%s\n", [(id)o revenantApplicationProtocolAt:1]);
        printf("alpn-2\t%s\n", [(id)o revenantApplicationProtocolAt:2]);
        want("alpn-past-end", [(id)o revenantApplicationProtocolAt:9] ? 1 : 0, 0);
        sec_protocol_options_add_tls_application_protocol(o, NULL);
        want("alpn-after-null", (long)[(id)o revenantApplicationProtocolCount], 3);

        sec_protocol_options_set_tls_server_name(o, "second.invalid");
        printf("name-after-second\t%s\n", [(id)o revenantServerName]);
        sec_protocol_options_set_tls_server_name(o, NULL);
        want("name-cleared", [(id)o revenantServerName] ? 1 : 0, 0);

        sec_protocol_options_set_tls_server_name(NULL, "x");
        sec_protocol_options_add_tls_application_protocol(NULL, "x");
        printf("null-options\t1\n");

        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
