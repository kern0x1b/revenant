#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <dlfcn.h>
#include "port-store-rule.h"
#include "ASPortCredentialExchange.h"
#import <objc/runtime.h>
#include <objc/message.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static const char *const kPortOpenID = "PortASAuthorizationOpenIDRequest";
static const char *const kPortAppleID = "PortASAuthorizationAppleIDRequest";

static const char *const kImplicitOperation = "ASAuthorizationOperationImplicit";

static id ask(id target, const char *name)
{
    SEL selector = sel_registerName(name);
    if (![target respondsToSelector:selector]) {
        printf("  FAIL %s does not answer -%s\n", class_getName(object_getClass([target class])), name);
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static void set(id target, const char *name, id value)
{
    char setter[128];
    const char *upper = name;
    snprintf(setter, sizeof setter, "set%c%s:", (upper[0] >= 'a' && upper[0] <= 'z') ? (char)(upper[0] - 32) : upper[0],
             upper + 1);
    SEL selector = sel_registerName(setter);
    if (![target respondsToSelector:selector]) {
        printf("  FAIL %s does not answer -%s\n", class_getName(object_getClass([target class])), setter);
        return;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, value);
}

static void report(const char *label, int onHost, id providerForThisSide, Class openID, Class appleID, id implicitOperation)
{
    Method initMethod = class_getInstanceMethod([openID class], sel_registerName("init"));
    printf("%s\n", label);
    printf("  built   request class          %s\n", class_getName(openID));
    printf("  built   -init imp            %p\n", initMethod ? (void *)method_getImplementation(initMethod) : (void *)0);
    id request = onHost
        ? ((id (*)(id, SEL))objc_msgSend)(providerForThisSide, sel_registerName("createRequest"))
        : ((id (*)(id, SEL))objc_msgSend)(providerForThisSide, sel_registerName("createRequest"));
    if (!request) {
        printf("  FAIL no request could be made from %s\n", class_getName(openID));
        return;
    }
    if (!request) {
        printf("  FAIL no request could be made from %s\n", class_getName(openID));
        return;
    }
    printf("  fresh   requestedScopes        %s\n", ask(request, "requestedScopes") ? "set" : "nil");
    printf("  fresh   state                  %s\n", ask(request, "state") ? "set" : "nil");
    printf("  fresh   nonce                  %s\n", ask(request, "nonce") ? "set" : "nil");
    printf("  fresh   requestedOperation   %s\n", ask(request, "requestedOperation") ? "set" : "nil");

    set(request, "state", @"the state");
    set(request, "nonce", @"the nonce");
    set(request, "requestedScopes", (@[ @"fullName", @"email" ]));
    set(request, "requestedOperation", implicitOperation);

    id copy = ask(request, "copy");
    printf("  copy    requestedScopes         %s\n", ask(copy, "requestedScopes") ? "set" : "nil");
    printf("  copy    state                   %s\n", ask(copy, "state") ? "set" : "nil");
    printf("  copy    nonce                  %s\n", ask(copy, "nonce") ? "set" : "nil");
    printf("  copy    requestedOperation    %s\n", ask(copy, "requestedOperation") ? "set" : "nil");

    if (appleID) {
        id apple = onHost
            ? ((id (*)(id, SEL))objc_msgSend)(providerForThisSide, sel_registerName("createRequest"))
            : ((id (*)(id, SEL))objc_msgSend)(providerForThisSide, sel_registerName("createRequest"));
        if (!apple) {
            printf("  FAIL no request could be made from %s\n", class_getName(appleID));
            return;
        }
        printf("  fresh   user                   %s\n", ask(apple, "user") ? "set" : "nil");
        set(apple, "user", @"001234.abcdef.0000");
        id appleCopy = ask(apple, "copy");
        printf("  copy    user                    %s\n", ask(appleCopy, "user") ? "set" : "nil");
    }
}

static NSInteger self_identities(const char *path)
{
    NSData *data = [NSData dataWithContentsOfFile:@(path)];
    if (!data)
        return 0;
    id held = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    return [held isKindOfClass:[NSArray class]] ? (NSInteger)[held count] : 0;
}

static const char *const kWritingSelectors[] = {
    "saveCredentialIdentities:completion:",
    "removeCredentialIdentities:completion:",
    "removeAllCredentialIdentitiesWithCompletion:",
    "replaceCredentialIdentitiesWithIdentities:completion:",
    NULL
};

#define PORT_STORE_PREFIX "Port"

static void port_store_send(id receiver, SEL selector, id first, void (^completion)(BOOL, NSError *))
{
    if (!port_store_receiver_is_the_ports(receiver, PORT_STORE_PREFIX)) {
        for (int index = 0; kWritingSelectors[index]; ++index) {
            if (strcmp(kWritingSelectors[index], sel_getName(selector)) == 0) {
                fprintf(stderr, "REFUSED: -%s was about to be sent to %s, which is not the port's "
                                "store, and this machine's store writes this Mac's AutoFill\n",
                        sel_getName(selector), port_store_receiver_class(receiver));
                abort();
            }
        }
    }
    ((void (*)(id, SEL, id, id))objc_msgSend)(receiver, selector, first, completion);
}

static NSInteger self_identities(const char *path);

static int store_case(void)
{
    const char *path = [NSProcessInfo.processInfo.environment[@"AS_CREDENTIAL_STORE_PATH"] UTF8String];
    if (!path) { printf("  FAIL no AS_CREDENTIAL_STORE_PATH, so the store case cannot run\n"); return 1; }
    [[NSFileManager defaultManager] removeItemAtPath:@(path) error:NULL];

    Class storeClass = NSClassFromString(@"PortASCredentialIdentityStore");
    Class serviceClass = NSClassFromString(@"PortASCredentialServiceIdentifier");
    Class identityClass = NSClassFromString(@"PortASPasswordCredentialIdentity");
    if (!storeClass || !serviceClass || !identityClass) {
        printf("  FAIL the port's store, service identifier or identity class is not linked in\n");
        return 1;
    }
    id store = ((id (*)(id, SEL))objc_msgSend)(storeClass, sel_registerName("sharedStore"));

    id serviceA = [[serviceClass alloc] initWithIdentifier:@"first.example" type:0];
    id serviceB = [[serviceClass alloc] initWithIdentifier:@"second.example" type:0];
    id (*makeIdentity)(id, SEL, id, id, id) = (id (*)(id, SEL, id, id, id))objc_msgSend;
    SEL make = sel_registerName("identityWithServiceIdentifier:user:recordIdentifier:");
    id first = makeIdentity(identityClass, make, serviceA, @"alice", nil);
    id second = makeIdentity(identityClass, make, serviceB, @"bob", nil);
    id third = makeIdentity(identityClass, make, serviceA, @"carol", nil);

    id pathObject = ((id (*)(id, SEL))objc_msgSend)(store, sel_registerName("revenant_storePath"));
    printf("  store   path            %s\n", [[pathObject description] UTF8String]);

    port_store_send(store, sel_registerName("saveCredentialIdentities:completion:"),
                    [NSArray arrayWithObject:first], ^(BOOL ok, NSError *error) { (void)ok; (void)error; });
    port_store_send(store, sel_registerName("saveCredentialIdentities:completion:"),
                    [NSArray arrayWithObject:second], ^(BOOL ok, NSError *error) { (void)ok; (void)error; });
    {
        Class credentialClass = NSClassFromString(@"PortASPasswordCredential");
        if (!credentialClass) { printf("  FAIL the port's password credential is not linked in\n"); return 1; }
        SEL makeSel = sel_registerName("initWithUser:password:");
        id (*make)(id, SEL, id, id) = (id (*)(id, SEL, id, id))objc_msgSend;
        id allocated = ((id (*)(id, SEL))objc_msgSend)((id)credentialClass, sel_registerName("alloc"));
        id credential = make(allocated, makeSel, @"alice", @"correct horse");
        id credentialCopy = ask(credential, "copy");
        printf("  store   credential fresh user %s\n", [ask(credential, "user") UTF8String] ?: "nil");
        printf("  store   credential fresh pass %s\n", [ask(credential, "password") UTF8String] ?: "nil");
        printf("  store   credential copy  pass %s\n", [ask(credentialCopy, "password") UTF8String] ?: "nil");
    }
    {
        Class contextClass = NSClassFromString(@"PortASCredentialProviderExtensionContext");
        if (!contextClass) { printf("  FAIL the port's provider context is not linked in\n"); return 1; }
        id (*complete)(id, SEL, id, void (^)(BOOL)) =
            (id (*)(id, SEL, id, void (^)(BOOL)))objc_msgSend;
        id (*exchangeOf)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        BOOL (*flag)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        id (*errorOf)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
        Class credentialClass = NSClassFromString(@"PortASPasswordCredential");
        id (*make)(id, SEL, id, id) = (id (*)(id, SEL, id, id))objc_msgSend;
        id credential = make(((id (*)(id, SEL))objc_msgSend)((id)credentialClass, sel_registerName("alloc")),
                             sel_registerName("initWithUser:password:"), @"alice", @"correct horse");
        id context = ((id (*)(id, SEL))objc_msgSend)((id)contextClass, sel_registerName("alloc"));
        __block BOOL recorded = NO;
        complete(context, sel_registerName("completeRequestWithSelectedCredential:completionHandler:"),
                 credential, ^(BOOL expired) { recorded = expired; });
        id exchange = exchangeOf(context, sel_registerName("lastExchange"));
        id held = ask(exchange, "credential");
        printf("  context  credential user  %s\n", [ask(held, "user") UTF8String] ?: "nil");
        printf("  context  handler answered  %s\n", recorded ? "yes" : "no");
        printf("  context  exchange flags  cancelled %s configuration %s\n",
               flag(exchange, sel_registerName("cancelled")) ? "yes" : "no",
               flag(exchange, sel_registerName("configurationCompleted")) ? "yes" : "no");
        id cancelled = ((id (*)(id, SEL))objc_msgSend)((id)contextClass, sel_registerName("alloc"));
        errorOf(cancelled, sel_registerName("cancelRequestWithError:"),
                [NSError errorWithDomain:@"PortASProvider" code:42 userInfo:nil]);
        id after = exchangeOf(cancelled, sel_registerName("lastExchange"));
        NSError *afterError = (NSError *)ask(after, "error");
        printf("  context  after cancel  cancelled %s code %ld kept %s\n",
               flag(after, sel_registerName("cancelled")) ? "yes" : "no",
               (long)afterError.code, afterError ? "yes" : "no");
    }

    printf("  store   before replace  %d identities\n", (int)self_identities(path));

    port_store_send(store, sel_registerName("replaceCredentialIdentitiesWithIdentities:completion:"),
                    [NSArray arrayWithObject:third], ^(BOOL ok, NSError *error) { (void)ok; (void)error; });
    NSInteger after = self_identities(path);
    printf("  store   after replace   %d identities\n", (int)after);
    printf("  store   identities after replace %d\n", (int)after);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s <AuthenticationServices.framework>\n", argv[0]);
        return 2;
    }
    if (!dlopen(argv[1], RTLD_LAZY)) {
        fprintf(stderr, "%s: %s\n", argv[1], dlerror());
        return 1;
    }
    Class hostOpenID = objc_getClass("ASAuthorizationOpenIDRequest");
    Class hostApple = objc_getClass("ASAuthorizationAppleIDRequest");
    id hostImplicit = ASAuthorizationOperationImplicit;
    if (!hostOpenID || !hostImplicit) {
        fprintf(stderr, "the host's own classes or its implicit operation are not there\n");
        return 1;
    }
    id hostProvider = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(objc_getClass("ASAuthorizationAppleIDProvider"), sel_registerName("alloc")), sel_registerName("init"));
    if (!hostProvider) { fprintf(stderr, "the host provider could not be made\n"); return 1; }
    report("host", 1, hostProvider, hostOpenID, hostApple, hostImplicit);

    Class portOpenID = NSClassFromString([NSString stringWithUTF8String:kPortOpenID]);
    Class portApple = NSClassFromString([NSString stringWithUTF8String:kPortAppleID]);
    if (!portOpenID) {
        fprintf(stderr, "the port's %s is not linked into this test\n", kPortOpenID);
        return 1;
    }
    id portProvider = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)
        (NSClassFromString([NSString stringWithUTF8String:"PortASAuthorizationAppleIDProvider"]), sel_registerName("alloc")),
        sel_registerName("init"));
    if (!portProvider) { fprintf(stderr, "the port's own provider could not be made\n"); return 1; }
    report("port", 0, portProvider, portOpenID, portApple, hostImplicit);
    if (store_case() != 0)
        return 1;
    return 0;
}
