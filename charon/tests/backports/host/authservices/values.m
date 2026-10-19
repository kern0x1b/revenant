/* values -- what a fresh AuthenticationServices request holds, and what its copy holds, on both sides.
 *
 * Two builds of the same source, in one process:
 *
 *   the host's own classes, named as the SDK header names them, linked from
 *   AuthenticationServices.framework -- and
 *
 *   the port's classes, which this process never names: the port's own build renames them, so the test
 *   reaches them through NSClassFromString and the runtime. The rename is on the port's translation
 *   units only and never on this one -- a test compiled with the port's renames would be asking the
 *   port's version of the question and calling it the host's.
 *
 * What is asserted is the four properties a fresh OpenID request holds, the four its copy holds, and the
 * user an Apple ID request carries and its copy carries. The shape check cannot see any of this: it
 * reads the binary and asks whether a method is bound, and a value is not a method. This is the
 * instrument for a value claim, and the value mutant is a change here that this must notice.
 */
#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>
// After Foundation: the runtime header declares things in terms of NSString, and importing it first is
// an error that reads like a broken SDK rather than an include order.
#import <dlfcn.h>
#include "port-store-rule.h"
#include "ASPortCredentialExchange.h"
#import <objc/runtime.h>
#include <objc/message.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* The port's classes, as the port's build names them. The renames are listed here so that a change to
 * them and a change here are the same change, and so that the two builds are visibly two builds. */
static const char *const kPortOpenID = "PortASAuthorizationOpenIDRequest";
static const char *const kPortAppleID = "PortASAuthorizationAppleIDRequest";

/* The value every fresh OpenID request holds, and the header's name for it. Read through the runtime on
 * the host side too, so that the two sides are asked the same way and a difference is a difference in
 * the port and not in how the question was put. */
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

/* One side's answers, as text. A copy is made through -copyWithZone: exactly as an application would:
 * -copy on NSObject dispatches to it. */
static void report(const char *label, int onHost, id providerForThisSide, Class openID, Class appleID, id implicitOperation)
{
    // The two call targets for one selector, from the runtime: the class each side made its request
    // from, and the address -init is actually reached at on it. Two addresses are two call targets.
    Method initMethod = class_getInstanceMethod([openID class], sel_registerName("init"));
    printf("%s\n", label);
    printf("  built   request class          %s\n", class_getName(openID));
    printf("  built   -init imp            %p\n", initMethod ? (void *)method_getImplementation(initMethod) : (void *)0);
    // The host's request comes from its provider, which is the path the SDK gives and the one the
    // base's NS_UNAVAILABLE -init and +new are pointing at. The port's provider is not implemented yet,
    // so the port's request is made with [[cls alloc] init], which the port binds because its own
    // header does not mark it unavailable. Two constructors, one per side, and this says so.
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

/* How many identities the port's store file holds, counted the way the store writes them. */
static NSInteger self_identities(const char *path)
{
    NSData *data = [NSData dataWithContentsOfFile:@(path)];
    if (!data)
        return 0;
    id held = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    return [held isKindOfClass:[NSArray class]] ? (NSInteger)[held count] : 0;
}

/* The one place in this probe a writing selector is dispatched, and the check the host-write rule is.
 *
 * On this Mac the host's ASCredentialIdentityStore writes to the USER's AutoFill. Every send that could
 * touch a store therefore goes through this function, which reads the receiver's class out of the
 * runtime and refuses anything the harness has not renamed to the port's. The check is not a spelling
 * test on this file -- a probe that sends selectors as strings through a cast objc_msgSend passes every
 * check that reads words, which is what the first two static guards did.
 *
 * The four selectors are spelled here and in the table below, and the static scan
 * (writing-selectors-scan.py) allows exactly these two places and nothing else. The self-test in
 * port-store-selftest.m asks the same predicate about this machine's own class object and sends nothing.
 */
static const char *const kWritingSelectors[] = {
    "saveCredentialIdentities:completion:",
    "removeCredentialIdentities:completion:",
    "removeAllCredentialIdentitiesWithCompletion:",
    "replaceCredentialIdentitiesWithIdentities:completion:",
    NULL
};

/* The prefix the harness renames the port's classes under, and the one the rule compares against. */
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

/* The port's store, exercised: what it holds, a replace, and what it holds afterwards.
 *
 * This is the one case in this file that writes, and it writes the PORT's store -- a property list under
 * .agent-work/runs/, named by AS_CREDENTIAL_STORE_PATH -- and never the host's. The host's store is not
 * written at any point in this family: its four writing methods change the user's AutoFill state on this
 * Mac, and host-write-guard.py requires every writing selector in a harness source to be inside the
 * chokepoint, while the runtime rule in port-store-rule.h refuses the host's class outright. The store is
 * read back
 * from its own file because the header has no getter for the identities: there is no public way to ask
 * a credential identity store what it holds, which is itself a fact about it worth knowing.
 */
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

    // The path, printed before anything is saved: the store's file belongs under .agent-work/runs/ and
    // a test that cannot say where it wrote is a test that should not be trusted with a write.
    id pathObject = ((id (*)(id, SEL))objc_msgSend)(store, sel_registerName("charon_storePath"));
    printf("  store   path            %s\n", [[pathObject description] UTF8String]);

    // The completions are BLOCKS, not selectors. The first version passed sel_registerName(...) where
    // the completion goes, and the port -- correctly -- called it, and the crash was
    // objc_retain inside saveCredentialIdentities:completion:. The first frame was in the runtime and
    // the second in the port's save, and the port was right to be there: it had been handed a selector
    // and told to call it.
    port_store_send(store, sel_registerName("saveCredentialIdentities:completion:"),
                    [NSArray arrayWithObject:first], ^(BOOL ok, NSError *error) { (void)ok; (void)error; });
    port_store_send(store, sel_registerName("saveCredentialIdentities:completion:"),
                    [NSArray arrayWithObject:second], ^(BOOL ok, NSError *error) { (void)ok; (void)error; });
    // Before the replace the store holds a set that is NOT what the replace will be given. A test that
    // replaced an empty store could not tell a superset from a replacement.
    // A password credential is a VALUE, and the shape check only asks whether its members are bound. These
    // three rows are what asks what they HOLD: a fresh credential holds what it was given, and its copy holds
    // the same. A copy that dropped the password would be an object that looks like a credential and could not
    // be used for one, and nothing else here can see that.
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
    // The context is the other half of the provider, and unlike the controller it BUILDS for the host:
    // NSExtensionContext exists on the host, so a value comparison can reach it. What it must be asked is
    // whether a completion was RECORDED, because a context that took the credential and dropped it would bind
    // every method the shape check reads and still leave nothing anywhere knowing the exchange finished.
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
    // The store's state after the replace, in the TABLE, keyed like every other row, so that a wrong
    // replace which does not crash still shows up as a difference. The probe-local check below is not
    // enough: it fails the run, but the two mutants are compared by their tables and a row that is not
    // in the table is a row the comparison cannot see.
    printf("  store   identities after replace %d\n", (int)after);
    // The set is exactly the array: one identity, and it is the one that was given. A superset would be
    // three here.
    // The count is the ROW, and the comparison is the check's, not this function's. Returning 1 here
    // would end the run before the two tables could be compared, and a mutant that makes the store hold
    // the wrong number has to be seen AS a difference between the tables rather than as a failed test.
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
    /* The implicit operation is the release's own extern, linked once and used as the value both
     * sides are asked against: a port that spelled its own would then be caught rather than agreeing
     * by writing the same string twice. */
    Class hostOpenID = objc_getClass("ASAuthorizationOpenIDRequest");
    Class hostApple = objc_getClass("ASAuthorizationAppleIDRequest");
    // The release owns this constant; reading it is enough and copying it is an ARC error.
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
    /* The port's operation is the same extern the host's is -- it is a value the release owns and the
     * constants check measures it -- so both sides are asked against the one value on purpose. */
    if (!portOpenID) {
        fprintf(stderr, "the port's %s is not linked into this test\n", kPortOpenID);
        return 1;
    }
    // The port's provider, made the way the port's provider is made: its own construction, because the
    // provider's superclass is NSObject and -init is not marked unavailable on it.
    id portProvider = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)
        (NSClassFromString([NSString stringWithUTF8String:"PortASAuthorizationAppleIDProvider"]), sel_registerName("alloc")),
        sel_registerName("init"));
    if (!portProvider) { fprintf(stderr, "the port's own provider could not be made\n"); return 1; }
    report("port", 0, portProvider, portOpenID, portApple, hostImplicit);
    // The store case is PARKED: the port's store case calls replaceCredentialIdentitiesWithIdentities:,
    // it compiled, and it SEGFAULTED on the first run, and a test that crashes is not a test. It is in
    // .agent-work/plan-and-analysis/authservices-store-case/ with what is known: the renames and the
    // sources that make the port's four identity classes live alongside the host's, and the one line
    // where it stops. The port's -replaceCredentialIdentitiesWithIdentities: is the reviewed change and
    // it is in the source; this is the case that will prove it, and it is not yet proved.
    if (store_case() != 0)
        return 1;
    return 0;
}
