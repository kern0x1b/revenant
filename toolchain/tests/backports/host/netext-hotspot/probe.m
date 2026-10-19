#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#if HOST_SIDE
#import <NetworkExtension/NetworkExtension.h>
#else
#import "RevenantNEHotspot.h"
#endif

static void wait_for(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void line(const char *name, id value)
{
    NSString *text = value ? [[value description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] : @"(nil)";
    printf("%s\t%s\n", name, [text UTF8String]);
}

static void owner(const char *name, IMP imp)
{
    Dl_info info;
    const char *image = (imp && dladdr((const void *)imp, &info) && info.dli_fname) ? info.dli_fname : "(none)";
    printf("dladdr\t%s\t%s\n", name, strrchr(image, '/') ? strrchr(image, '/') + 1 : image);
}

static void network(void)
{
    NEHotspotNetwork *n = [[NEHotspotNetwork alloc] init];
    line("network.class", NSStringFromClass([n class]));
    printf("network.securityType\t%ld\n", (long)n.securityType);
    printf("network.signalStrength\t%g\n", n.signalStrength);
    printf("network.isSecure\t%d\n", n.isSecure);
    printf("network.didAutoJoin\t%d\n", n.didAutoJoin);
    printf("network.didJustJoin\t%d\n", n.didJustJoin);
    printf("network.isChosenHelper\t%d\n", n.isChosenHelper);
    [n setConfidence:kNEHotspotHelperConfidenceHigh];
    [n setPassword:@"pw"];
    printf("network.setters\tdone\n");
    line("network.SSID", n.SSID);
    line("network.BSSID", n.BSSID);
    owner("setConfidence", [n methodForSelector:@selector(setConfidence:)]);
    owner("setPassword", [n methodForSelector:@selector(setPassword:)]);
}

static void config(void)
{
    NEHotspotConfiguration *c = [[NEHotspotConfiguration alloc] initWithSSID:@"revenant-probe"];
    line("config.SSID", c.SSID);
    line("config.SSIDPrefix", c.SSIDPrefix);
    printf("config.hidden\t%d\n", c.hidden);
    printf("config.joinOnce\t%d\n", c.joinOnce);
    line("config.lifeTimeInDays", c.lifeTimeInDays);
    NEHotspotConfiguration *p = [[NEHotspotConfiguration alloc] initWithSSIDPrefix:@"pre"];
    line("prefix.SSID", p.SSID);
    line("prefix.SSIDPrefix", p.SSIDPrefix);
    NEHotspotConfiguration *w = [[NEHotspotConfiguration alloc] initWithSSID:@"wep" passphrase:@"pw" isWEP:YES];
    line("wep.SSID", w.SSID);
    c.joinOnce = YES;
    c.hidden = YES;
    c.lifeTimeInDays = @5;
    printf("set.joinOnce\t%d\nset.hidden\t%d\n", c.joinOnce, c.hidden);
    line("set.lifeTimeInDays", c.lifeTimeInDays);
    NEHotspotConfiguration *copy = [c copy];
    printf("copy.isSameObject\t%d\n", copy == c);
    line("copy.class", NSStringFromClass([copy class]));
    printf("copy.joinOnce\t%d\ncopy.hidden\t%d\n", copy.joinOnce, copy.hidden);
    line("copy.lifeTimeInDays", copy.lifeTimeInDays);
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:c requiringSecureCoding:YES error:&err];
    printf("archive.hasData\t%d\n", data != nil);
    line("archive.error", err);
    NEHotspotConfiguration *back = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NEHotspotConfiguration class] fromData:data error:&err] : nil;
    line("roundTrip.class", NSStringFromClass([back class]));
    line("roundTrip.SSID", back.SSID);
    printf("roundTrip.joinOnce\t%d\nroundTrip.hidden\t%d\n", back.joinOnce, back.hidden);
    line("roundTrip.lifeTimeInDays", back.lifeTimeInDays);
    owner("initWithSSID", [NEHotspotConfiguration instanceMethodForSelector:@selector(initWithSSID:)]);
    owner("initWithSSIDPrefix", [NEHotspotConfiguration instanceMethodForSelector:@selector(initWithSSIDPrefix:)]);
}

static void fetch(void)
{
    owner("fetchCurrent", [NEHotspotNetwork methodForSelector:@selector(fetchCurrentWithCompletionHandler:)]);
    __block int calls = 0;
    __block id got = nil;
    __block int main = -1;
    __block BOOL returned = NO;
    __block int beforeReturn = -1;
    [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork *current) {
        calls++;
        got = current;
        main = [NSThread isMainThread];
        beforeReturn = !returned;
    }];
    returned = YES;
    wait_for(3);
    printf("fetch.calls\t%d\n", calls);
    line("fetch.network", got);
    printf("fetch.onMainThread\t%d\n", main);
    printf("fetch.beforeReturn\t%d\n", beforeReturn);
}

static void apply(void)
{
    NEHotspotConfiguration *c = [[NEHotspotConfiguration alloc] initWithSSID:@"revenant-probe-no-such-ssid"];
    __block int calls = 0;
    __block NSError *err = nil;
    __block int main = -1;
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:c completionHandler:^(NSError *e) {
        calls++;
        err = e;
        main = [NSThread isMainThread];
    }];
    wait_for(5);
    printf("apply.calls\t%d\n", calls);
    printf("apply.errorDomain\t%s\n", err ? [err.domain UTF8String] : "(nil)");
    printf("apply.errorCode\t%ld\n", err ? (long)err.code : 0L);
    printf("apply.onMainThread\t%d\n", main);
}

static void configured(void)
{
    __block int calls = 0;
    __block id got = nil;
    [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> *ssids) {
        calls++;
        got = ssids;
    }];
    wait_for(5);
    printf("configured.calls\t%d\n", calls);
    line("configured.ssids", got);
}

static void helper(void)
{
    __block int calls = 0;
    BOOL ok = [NEHotspotHelper registerWithOptions:nil queue:dispatch_get_main_queue() handler:^(NEHotspotHelperCommand *cmd) {
        calls++;
    }];
    wait_for(3);
    printf("register.returned\t%d\n", ok);
    printf("register.handlerCalls\t%d\n", calls);
    line("supportedNetworkInterfaces", [NEHotspotHelper supportedNetworkInterfaces]);
    printf("logoff.returned\t%d\n", [NEHotspotHelper logoff:[[NEHotspotNetwork alloc] init]]);
}

static void removes(void)
{
    NEHotspotConfigurationManager *m = [NEHotspotConfigurationManager sharedManager];
    printf("shared.same\t%d\n", m == [NEHotspotConfigurationManager sharedManager]);
    line("shared.class", NSStringFromClass([m class]));
    [m removeConfigurationForSSID:@"revenant-probe-no-such-ssid"];
    printf("remove.ssid.returned\t1\n");
    [m removeConfigurationForHS20DomainName:@"revenant-probe-no-such-domain"];
    printf("remove.hs20.returned\t1\n");
}

static void command(void)
{
    NEHotspotHelperCommand *cmd = [[NEHotspotHelperCommand alloc] init];
    line("command.class", NSStringFromClass([cmd class]));
    printf("command.commandType\t%ld\n", (long)cmd.commandType);
    line("command.network", cmd.network);
    line("command.networkList", cmd.networkList);
    line("command.createResponse", [cmd createResponse:kNEHotspotHelperResultSuccess]);
    id endpoint = nil;
    line("command.createTCPConnection", [cmd createTCPConnection:endpoint]);
    line("command.createUDPSession", [cmd createUDPSession:endpoint]);
}

static void response(void)
{
    NEHotspotHelperResponse *r = [[NEHotspotHelperResponse alloc] init];
    line("response.class", NSStringFromClass([r class]));
    [r setNetwork:[[NEHotspotNetwork alloc] init]];
    [r setNetworkList:@[]];
    [r deliver];
    printf("response.delivered\t1\n");
}

static void bind_request(void)
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com/"]];
    line("bind.before", request.allHTTPHeaderFields);
    [request bindToHotspotHelperCommand:[[NEHotspotHelperCommand alloc] init]];
    line("bind.after", request.allHTTPHeaderFields);
}

static void holds(const char *name, NSData *data, NSString *text)
{
    BOOL found = data && [data rangeOfData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0
                                      range:NSMakeRange(0, data.length)].location != NSNotFound;
    printf("%s\t%d\n", name, found);
}

static void eap(void)
{
    NEHotspotEAPSettings *e = [[NEHotspotEAPSettings alloc] init];
    line("eap.class", NSStringFromClass([e class]));
    line("eap.supportedEAPTypes", e.supportedEAPTypes);
    line("eap.username", e.username);
    line("eap.outerIdentity", e.outerIdentity);
    printf("eap.ttlsInnerAuthenticationType\t%ld\n", (long)e.ttlsInnerAuthenticationType);
    line("eap.password", e.password);
    line("eap.trustedServerNames", e.trustedServerNames);
    printf("eap.tlsClientCertificateRequired\t%d\n", e.tlsClientCertificateRequired);
    printf("eap.preferredTLSVersion\t%ld\n", (long)e.preferredTLSVersion);
    NSMutableArray *types = [@[@(NEHotspotConfigurationEAPTypeEAPTTLS)] mutableCopy];
    NSMutableString *user = [@"alice" mutableCopy];
    NSMutableArray *names = [@[@"srv.example"] mutableCopy];
    e.supportedEAPTypes = types;
    e.username = user;
    e.password = @"probe-secret";
    e.outerIdentity = @"anon";
    e.trustedServerNames = names;
    e.ttlsInnerAuthenticationType = NEHotspotConfigurationEAPTTLSInnerAuthenticationMSCHAPv2;
    e.tlsClientCertificateRequired = YES;
    e.preferredTLSVersion = NEHotspotConfigurationEAPTLSVersion_1_2;
    [types addObject:@(NEHotspotConfigurationEAPTypeEAPPEAP)];
    [user appendString:@"-mutated"];
    [names addObject:@"other.example"];
    printf("set.supportedEAPTypes.count\t%lu\n", (unsigned long)e.supportedEAPTypes.count);
    line("set.username", e.username);
    printf("set.trustedServerNames.count\t%lu\n", (unsigned long)e.trustedServerNames.count);
    line("set.password", e.password);
    line("set.outerIdentity", e.outerIdentity);
    printf("set.ttlsInnerAuthenticationType\t%ld\n", (long)e.ttlsInnerAuthenticationType);
    printf("set.tlsClientCertificateRequired\t%d\n", e.tlsClientCertificateRequired);
    printf("set.preferredTLSVersion\t%ld\n", (long)e.preferredTLSVersion);
    SecIdentityRef noIdentity = NULL;
    NSArray *noCertificates = nil;
    printf("identity.nil\t%d\n", [e setIdentity:noIdentity]);
    printf("certs.nil\t%d\n", [e setTrustedServerCertificates:noCertificates]);
    printf("certs.empty\t%d\n", [e setTrustedServerCertificates:@[]]);
    NEHotspotEAPSettings *c = [e copy];
    printf("copy.isSameObject\t%d\n", c == e);
    line("copy.class", NSStringFromClass([c class]));
    line("copy.supportedEAPTypes", c.supportedEAPTypes);
    line("copy.username", c.username);
    line("copy.password", c.password);
    line("copy.outerIdentity", c.outerIdentity);
    line("copy.trustedServerNames", c.trustedServerNames);
    printf("copy.ttlsInnerAuthenticationType\t%ld\n", (long)c.ttlsInnerAuthenticationType);
    printf("copy.tlsClientCertificateRequired\t%d\n", c.tlsClientCertificateRequired);
    printf("copy.preferredTLSVersion\t%ld\n", (long)c.preferredTLSVersion);
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:e requiringSecureCoding:YES error:&err];
    printf("archive.hasData\t%d\n", data != nil);
    line("archive.error", err);
    holds("archive.holdsPassword", data, @"probe-secret");
    NEHotspotEAPSettings *back = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NEHotspotEAPSettings class] fromData:data error:&err] : nil;
    line("roundTrip.class", NSStringFromClass([back class]));
    line("roundTrip.supportedEAPTypes", back.supportedEAPTypes);
    line("roundTrip.username", back.username);
    line("roundTrip.password", back.password);
    line("roundTrip.outerIdentity", back.outerIdentity);
    line("roundTrip.trustedServerNames", back.trustedServerNames);
    printf("roundTrip.ttlsInnerAuthenticationType\t%ld\n", (long)back.ttlsInnerAuthenticationType);
    printf("roundTrip.tlsClientCertificateRequired\t%d\n", back.tlsClientCertificateRequired);
    printf("roundTrip.preferredTLSVersion\t%ld\n", (long)back.preferredTLSVersion);
    owner("setIdentity", [NEHotspotEAPSettings instanceMethodForSelector:@selector(setIdentity:)]);
    owner("setTrustedServerCertificates", [NEHotspotEAPSettings instanceMethodForSelector:@selector(setTrustedServerCertificates:)]);
}

static void hs20(void)
{
    NEHotspotHS20Settings *h = [[NEHotspotHS20Settings alloc] initWithDomainName:@"example.com" roamingEnabled:YES];
    line("hs20.domainName", h.domainName);
    printf("hs20.roamingEnabled\t%d\n", h.roamingEnabled);
    line("hs20.roamingConsortiumOIs", h.roamingConsortiumOIs);
    line("hs20.naiRealmNames", h.naiRealmNames);
    line("hs20.MCCAndMNCs", h.MCCAndMNCs);
    NEHotspotHS20Settings *d = [[NEHotspotHS20Settings alloc] init];
    line("hs20.init.domainName", d.domainName);
    printf("hs20.init.roamingEnabled\t%d\n", d.roamingEnabled);
    line("hs20.init.roamingConsortiumOIs", d.roamingConsortiumOIs);
    NSMutableArray *oi = [@[@"5F2B3C"] mutableCopy];
    h.roamingConsortiumOIs = oi;
    h.naiRealmNames = @[@"realm.example"];
    h.MCCAndMNCs = @[@"310260"];
    [oi addObject:@"mutated"];
    printf("set.roamingConsortiumOIs.count\t%lu\n", (unsigned long)h.roamingConsortiumOIs.count);
    line("set.naiRealmNames", h.naiRealmNames);
    line("set.MCCAndMNCs", h.MCCAndMNCs);
    NEHotspotHS20Settings *c = [h copy];
    printf("copy.isSameObject\t%d\n", c == h);
    line("copy.class", NSStringFromClass([c class]));
    line("copy.domainName", c.domainName);
    printf("copy.roamingEnabled\t%d\n", c.roamingEnabled);
    line("copy.roamingConsortiumOIs", c.roamingConsortiumOIs);
    line("copy.naiRealmNames", c.naiRealmNames);
    line("copy.MCCAndMNCs", c.MCCAndMNCs);
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:h requiringSecureCoding:YES error:&err];
    printf("archive.hasData\t%d\n", data != nil);
    line("archive.error", err);
    NEHotspotHS20Settings *back = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NEHotspotHS20Settings class] fromData:data error:&err] : nil;
    line("roundTrip.class", NSStringFromClass([back class]));
    line("roundTrip.domainName", back.domainName);
    printf("roundTrip.roamingEnabled\t%d\n", back.roamingEnabled);
    line("roundTrip.roamingConsortiumOIs", back.roamingConsortiumOIs);
    line("roundTrip.naiRealmNames", back.naiRealmNames);
    line("roundTrip.MCCAndMNCs", back.MCCAndMNCs);
    owner("initWithDomainName", [NEHotspotHS20Settings instanceMethodForSelector:@selector(initWithDomainName:roamingEnabled:)]);
}

static void wiring(void)
{
    NEHotspotEAPSettings *e = [[NEHotspotEAPSettings alloc] init];
    e.username = @"alice";
    NEHotspotConfiguration *c1 = [[NEHotspotConfiguration alloc] initWithSSID:@"corp" eapSettings:e];
    line("eapinit.SSID", c1.SSID);
    line("eapinit.SSIDPrefix", c1.SSIDPrefix);
    printf("eapinit.joinOnce\t%d\n", c1.joinOnce);
    NEHotspotHS20Settings *h = [[NEHotspotHS20Settings alloc] initWithDomainName:@"example.com" roamingEnabled:NO];
    NEHotspotConfiguration *c2 = [[NEHotspotConfiguration alloc] initWithHS20Settings:h eapSettings:e];
    line("hs20init.SSID", c2.SSID);
    line("hs20init.SSIDPrefix", c2.SSIDPrefix);
    printf("hs20init.joinOnce\t%d\n", c2.joinOnce);
    unsigned int n = 0;
    Ivar *list = class_copyIvarList([NEHotspotConfiguration class], &n);
    for (unsigned int i = 0; i < n; i++) {
        const char *type = ivar_getTypeEncoding(list[i]);
        printf("ivar.%s\t%s\n", ivar_getName(list[i]), type);
        if (type[0] != '@') continue;
        id held = object_getIvar(c1, list[i]);
        printf("held.%s\t%s\n", ivar_getName(list[i]), held ? [NSStringFromClass([held class]) UTF8String] : "(nil)");
        printf("held.%s.same\t%d\n", ivar_getName(list[i]), held == e);
    }
    free(list);
    Ivar eapIvar = class_getInstanceVariable([NEHotspotConfiguration class], "_eapSettings");
    Ivar hs20Ivar = class_getInstanceVariable([NEHotspotConfiguration class], "_hs20Settings");
    line("held.c1.eap.username", [object_getIvar(c1, eapIvar) valueForKey:@"username"]);
    printf("held.c1.eap.same\t%d\n", object_getIvar(c1, eapIvar) == e);
    line("held.c2.eap.username", [object_getIvar(c2, eapIvar) valueForKey:@"username"]);
    printf("held.c2.eap.same\t%d\n", object_getIvar(c2, eapIvar) == e);
    line("held.c2.hs20.domainName", [object_getIvar(c2, hs20Ivar) valueForKey:@"domainName"]);
    printf("held.c2.hs20.same\t%d\n", object_getIvar(c2, hs20Ivar) == h);
    e.username = @"changed";
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:c1 requiringSecureCoding:YES error:&err];
    printf("archive.hasData\t%d\n", data != nil);
    line("archive.error", err);
    holds("archive.holdsEAPClass", data, @"NEHotspotEAPSettings");
    holds("archive.holdsUsername", data, @"changed");
    holds("archive.holdsSSID", data, @"corp");
    NEHotspotConfiguration *back = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NEHotspotConfiguration class] fromData:data error:&err] : nil;
    line("roundTrip.class", NSStringFromClass([back class]));
    line("roundTrip.SSID", back.SSID);
    line("roundTrip.eap.username", [object_getIvar(back, eapIvar) valueForKey:@"username"]);
    NEHotspotConfiguration *cc = [c2 copy];
    line("copy.hs20.domainName", [object_getIvar(cc, hs20Ivar) valueForKey:@"domainName"]);
    line("copy.eap.username", [object_getIvar(cc, eapIvar) valueForKey:@"username"]);
    NSData *data2 = [NSKeyedArchiver archivedDataWithRootObject:c2 requiringSecureCoding:YES error:&err];
    holds("archive.hs20.holdsHS20Class", data2, @"NEHotspotHS20Settings");
    NEHotspotConfiguration *b2 = data2 ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NEHotspotConfiguration class] fromData:data2 error:&err] : nil;
    line("roundTrip.hs20.SSID", b2.SSID);
    line("roundTrip.hs20.domainName", [object_getIvar(b2, hs20Ivar) valueForKey:@"domainName"]);
}

int main(int argc, const char *argv[])
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        const char *op = argc > 1 ? argv[1] : "";
        if (!strcmp(op, "network")) network();
        else if (!strcmp(op, "config")) config();
        else if (!strcmp(op, "fetch")) fetch();
        else if (!strcmp(op, "apply")) apply();
        else if (!strcmp(op, "configured")) configured();
        else if (!strcmp(op, "helper")) helper();
        else if (!strcmp(op, "remove")) removes();
        else if (!strcmp(op, "command")) command();
        else if (!strcmp(op, "response")) response();
        else if (!strcmp(op, "bind")) bind_request();
        else if (!strcmp(op, "eap")) eap();
        else if (!strcmp(op, "hs20")) hs20();
        else if (!strcmp(op, "wiring")) wiring();
        else { fprintf(stderr, "usage: probe network|config|fetch|apply|configured|helper|remove|command|response|bind|eap|hs20|wiring\n"); return 2; }
    }
    return 0;
}
