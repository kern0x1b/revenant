#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>

@interface RevenantSecProtocolFlags : NSObject <OS_sec_protocol_options>
- (void)revenantSet:(int)flag to:(BOOL)value;
- (BOOL)revenantGet:(int)flag;
@end

enum { F_TICKETS = 0, F_FALLBACK, F_RESUMPTION, F_FALSESTART, F_OCSP, F_SCT, F_RENEG, F_PEERAUTH };
static const int kFlags[] = { F_TICKETS, F_FALLBACK, F_RESUMPTION, F_FALSESTART,
                              F_OCSP, F_SCT, F_RENEG, F_PEERAUTH };
static const char *kNames[] = { "tickets", "fallback", "resumption", "falsestart",
                                "ocsp", "sct", "reneg", "peerauth" };
static int failures = 0;

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"RevenantSecProtocolFlags");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        for (int i = 0; i < 8; i++) {
            sec_protocol_options_t one = (sec_protocol_options_t)[[cls alloc] init];
            [(RevenantSecProtocolFlags *)one revenantSet:kFlags[i] to:YES];
            for (int j = 0; j < 8; j++) {
                BOOL got = [(RevenantSecProtocolFlags *)one revenantGet:kFlags[j]];
                if (got != (i == j)) {
                    printf("WRONG\t%s alone: %s read [%d] and only %s was set\n",
                           kNames[i], kNames[j], got ? 1 : 0, kNames[i]);
                    failures++;
                }
            }
            (void)o;
        }
        for (int i = 0; i < 8; i++)
            [(RevenantSecProtocolFlags *)o revenantSet:kFlags[i] to:YES];
        for (int i = 0; i < 8; i++) {
            printf("all-set-%s\t%d\n", kNames[i], [(RevenantSecProtocolFlags *)o revenantGet:kFlags[i]] ? 1 : 0);
        }
        [(RevenantSecProtocolFlags *)o revenantSet:F_OCSP to:NO];
        printf("cleared-ocsp\t%d\n", [(RevenantSecProtocolFlags *)o revenantGet:F_OCSP] ? 1 : 0);
        printf("neighbour-sct\t%d\n", [(RevenantSecProtocolFlags *)o revenantGet:F_SCT] ? 1 : 0);
        printf("neighbour-tickets\t%d\n", [(RevenantSecProtocolFlags *)o revenantGet:F_TICKETS] ? 1 : 0);

        weakOptions = o;
    }
    printf("deallocated\t%d\n", weakOptions ? 1 : 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
