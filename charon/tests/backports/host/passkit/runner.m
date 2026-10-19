// The PassKit probe: one case per Secure Element member, and the wallet's beside them.
//
// The port's categories are compiled onto classes RENAMED by the run (charonHost_PKPassLibrary and
// the rest), so every call below goes to the port's own code through the runtime and never to the
// host's PassKit. The host is not the oracle for the VALUE -- a Mac answers these from a real Secure
// Element and this device has none -- so a case checks the port's answer against what the port's
// registry rows promise. The host IS the oracle for one thing, and the last case uses it: PKPassKit
// ErrorDomain must be the host framework's own bytes, which is what makes "linked, not defined" a
// measured claim rather than a promise.
//
// Every case is one line, so a mutant that answers YES where a row says NO turns the transcript red.
// That is what makes "0 failures" mean something.
#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSUInteger gChecks = 0;
static NSUInteger gFailures = 0;

static void say(NSString *name, id value, NSString *expected)
{
    NSString *got = [value description];
    BOOL ok = [got isEqualToString:expected];
    gChecks++;
    if (!ok) {
        gFailures++;
    }
    printf("  %-56s %-26s %s\n", [name UTF8String], [got UTF8String], ok ? "" : "FAIL");
}

static void check(NSString *name, BOOL condition)
{
    gChecks++;
    if (!condition) {
        gFailures++;
    }
    printf("  %-56s %-26s %s\n", [name UTF8String], condition ? "yes" : "no",
           condition ? "" : "FAIL");
}

// The error's domain and code, so a transcript says which error it got without an address.
static NSString *shape(NSError *error)
{
    if (!error) {
        return @"nil";
    }
    return [NSString stringWithFormat:@"%@/%ld", [error domain], (long)[error code]];
}

// The port's own classes, reached by the names the run gave them.
#define PORT_CLASS(name) NSClassFromString([@"charonHost_" stringByAppendingString:(name)])
#define PORT_LIB_CLASS(name) PORT_CLASS(name)

static id portLib(void)
{
    Class c = PORT_LIB_CLASS(@"PKPassLibrary");
    return c ? [[c alloc] init] : nil;
}

// The argument the two canMakePaymentsUsingNetworks: pairs and the activation code are given. It is
// a real object, not a bare selector: ARC retains an `id` argument, and a SEL is not an object to
// retain, so passing one crashes in objc_retain before the port's code is ever reached.
static id probeArg(void)
{
    return @"probe";
}

// A class-level BOOL: +selector on the port's class.
static BOOL classBool(Class c, NSString *sel)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(c, NSSelectorFromString(sel));
}

// An instance-level BOOL: -selector on a fresh PKPassLibrary.
static BOOL instBool(NSString *sel)
{
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(portLib(), NSSelectorFromString(sel), @"x");
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        // The port's own dylib, loaded by the path the run hands over, so every class below is the
        // PORT's renamed class and not the host's PassKit, which is a different class entirely.
        const char *dylib = getenv("CHARON_PORT_DYLIB");
        if (dylib) {
            dlopen(dylib, RTLD_LOCAL);
        }
        printf("# transcript: the PassKit Secure Element and wallet, one case per member\n");

        Class pac = PORT_CLASS(@"PKPaymentAuthorizationController");
        Class pavc = PORT_CLASS(@"PKPaymentAuthorizationViewController");
        Class papvc = PORT_CLASS(@"PKAddPassesViewController");

        // THE TWO CLASSES, and the case that matters for each is not that a member answers: it is
        // that the class EXISTS at all. The 6.1.3 gate refused the categories these six members were
        // built in -- "categories whose class neither iOS 6.1.3 nor the package exports" -- because a
        // category on a class nobody carries is dead code. So each class is asked for by name, and a
        // nil there is a failure, not a detail.
        {
            Class controller = PORT_CLASS(@"PKPaymentAuthorizationController");
            Class viewController = PORT_CLASS(@"PKPaymentAuthorizationViewController");
            check(@"the controller class is carried, not absent",
                  controller != Nil);
            // The SUPERCLASS, and it is the header's own for each: the 26.2 header declares
            // @interface PKPaymentAuthorizationController : NSObject and, under TARGET_OS_IPHONE,
            // @interface PKPaymentAuthorizationViewController : UIViewController. This port is the iOS
            // one, so those are the two the release names.
            // The case NAMES the superclass it expects, so the transcript says what it is checking
            // and a reader can grep this file for "superclass" and find the check that uses it --
            // which is the whole reason it is worded this way and not "is a class this port defines".
            //
            // It is class_getSuperclass and NOT isSubclassOfClass, and the difference is the point: a
            // renamed SUBCLASS of the host's class would answer every capability question correctly and
            // pass an isSubclassOfClass test, while being a class the release never had -- the very
            // thing the release-split gate and the 6.1.3 gate object to. The superclass must be exactly
            // the one the header names. run.sh's fifth mutant is that subclass, the view controller
            // declared as a UIView, and it must go red naming the case.
            check(@"  ... and its superclass is NSObject, the header's own",
                  controller != Nil && class_getSuperclass(controller) == [NSObject class]);
            check(@"the view controller class is carried, not absent", viewController != Nil);
            check(@"  ... and its superclass is UIViewController, the header's own",
                  viewController != Nil && class_getSuperclass(viewController) == [UIViewController class]);
            // And the three questions each answers, through the runtime, on the port's own class.
            for (Class c in @[controller ?: [NSObject class], viewController ?: [NSObject class]]) {
                NSString *which = c == controller ? @"controller" : @"view controller";
                say([NSString stringWithFormat:@"%@.canMakePayments", which],
                    [NSNumber numberWithBool:((BOOL (*)(id, SEL))objc_msgSend)(c,
                        NSSelectorFromString(@"canMakePayments"))], @"0");
                say([NSString stringWithFormat:@"%@.canMakePaymentsUsingNetworks:", which],
                    [NSNumber numberWithBool:((BOOL (*)(id, SEL, id))objc_msgSend)(c,
                        NSSelectorFromString(@"canMakePaymentsUsingNetworks:"), @[])], @"0");
            }
            say(@"the view controller's 9.0 member",
                [NSNumber numberWithBool:((BOOL (*)(id, SEL, id, long))objc_msgSend)(viewController,
                    NSSelectorFromString(@"canMakePaymentsUsingNetworks:capabilities:"), @[], 0L)], @"0");
        }

        // The eleven capability questions, each NO.
        say(@"PAC.canMakePayments",
            [NSNumber numberWithBool:classBool(pac, @"canMakePayments")], @"0");
        say(@"PAC.canMakePaymentsUsingNetworks:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id))objc_msgSend)(
                pac, NSSelectorFromString(@"canMakePaymentsUsingNetworks:"), probeArg())], @"0");
        say(@"PAC.canMakePaymentsUsingNetworks:capabilities:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id, long))objc_msgSend)(
                pac, NSSelectorFromString(@"canMakePaymentsUsingNetworks:capabilities:"),
                probeArg(), 0L)], @"0");
        say(@"PAVC.canMakePayments",
            [NSNumber numberWithBool:classBool(pavc, @"canMakePayments")], @"0");
        say(@"PAVC.canMakePaymentsUsingNetworks:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id))objc_msgSend)(
                pavc, NSSelectorFromString(@"canMakePaymentsUsingNetworks:"), probeArg())], @"0");
        say(@"PAVC.canMakePaymentsUsingNetworks:capabilities:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id, long))objc_msgSend)(
                pavc, NSSelectorFromString(@"canMakePaymentsUsingNetworks:capabilities:"),
                probeArg(), 0L)], @"0");
        say(@"PKPassLibrary.isPaymentPassActivationAvailable",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL))objc_msgSend)(portLib(), NSSelectorFromString(@"isPaymentPassActivationAvailable"))], @"0");
        say(@"PKPassLibrary.paymentPassActivationAvailable",
            [NSNumber numberWithBool:classBool(PORT_LIB_CLASS(@"PKPassLibrary"), @"isPaymentPassActivationAvailable")], @"0");
        say(@"PKPassLibrary.canAddPaymentPassWithPrimaryAccountIdentifier:",
            [NSNumber numberWithBool:instBool(@"canAddPaymentPassWithPrimaryAccountIdentifier:")], @"0");
        say(@"PKPassLibrary.canAddSecureElementPassWithPrimaryAccountIdentifier:",
            [NSNumber numberWithBool:instBool(@"canAddSecureElementPassWithPrimaryAccountIdentifier:")], @"0");
        say(@"PKPassLibrary.canAddFelicaPass",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL))objc_msgSend)(portLib(), NSSelectorFromString(@"canAddFelicaPass"))], @"0");

        // The six operations, each answering with the release's own error. Four take a completion
        // whose block records the arguments it was handed, so the case is about the ANSWER.
        __block NSError *e = nil;
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"activatePaymentPass:withActivationCode:completion:"), nil,
            probeArg(), ^(BOOL ok, NSError *error) {
                say(@"PKPassLibrary.activatePaymentPass:withActivationCode: ok", [NSNumber numberWithBool:ok], @"0");
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        e = nil;
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"activatePaymentPass:withActivationData:completion:"), nil,
            probeArg(), ^(BOOL ok, NSError *error) {
                say(@"PKPassLibrary.activatePaymentPass:withActivationData: ok", [NSNumber numberWithBool:ok], @"0");
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        e = nil;
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"activateSecureElementPass:withActivationData:completion:"), nil,
            probeArg(), ^(BOOL ok, NSError *error) {
                say(@"PKPassLibrary.activateSecureElementPass:withActivationData: ok", [NSNumber numberWithBool:ok], @"0");
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        e = nil;
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"signData:withSecureElementPass:completion:"), nil,
            probeArg(), ^(NSData *signedData, NSData *signature, NSError *error) {
                check(@"PKPassLibrary.signData:...:completion: signedData", signedData == nil);
                check(@"PKPassLibrary.signData:...:completion: signature", signature == nil);
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        e = nil;
        ((void (*)(id, SEL, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"serviceProviderDataForSecureElementPass:completion:"), nil,
            ^(NSData *data, NSError *error) {
                check(@"PKPassLibrary.serviceProviderData...: data", data == nil);
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        e = nil;
        ((void (*)(id, SEL, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"encryptedServiceProviderDataForSecureElementPass:completion:"), nil,
            ^(NSDictionary *data, NSError *error) {
                check(@"PKPassLibrary.encryptedServiceProviderData...: data", data == nil);
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        // presentSecureElementPass: has no completion, so the return value is the whole answer.
        say(@"PKPassLibrary.presentSecureElementPass:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id))objc_msgSend)(
                portLib(), NSSelectorFromString(@"presentSecureElementPass:"), nil)], @"0");

        // The wallet's own members. The empty set is not nil, and the pair of cases says which it is.
        NSArray *passes = ((id (*)(id, SEL, id))objc_msgSend)(
            PORT_LIB_CLASS(@"PKPassLibrary"), NSSelectorFromString(@"passesOfType:"), @"coupon");
        say(@"PKPassLibrary.passesOfType: count", [NSNumber numberWithUnsignedInteger:[passes count]], @"0");
        check(@"PKPassLibrary.passesOfType: is not nil", passes != nil);

        e = nil;
        ((void (*)(id, SEL, id, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"addPasses:withCompletionHandler:"), @[],
            ^(BOOL added, NSError *error) {
                say(@"PKPassLibrary.addPasses:withCompletionHandler: added", [NSNumber numberWithBool:added], @"0");
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        say(@"PKAddPassesViewController.canAddPasses",
            [NSNumber numberWithBool:classBool(papvc, @"canAddPasses")], @"0");
        NSArray *remote = ((id (*)(id, SEL))objc_msgSend)(
            PORT_LIB_CLASS(@"PKPassLibrary"), NSSelectorFromString(@"remotePaymentPasses"));
        say(@"PKPassLibrary.remotePaymentPasses count", [NSNumber numberWithUnsignedInteger:[remote count]], @"0");
        say(@"PKPassLibrary.isSuppressingAutomaticPassPresentation",
            [NSNumber numberWithBool:classBool(PORT_LIB_CLASS(@"PKPassLibrary"),
                                              @"isSuppressingAutomaticPassPresentation")], @"0");

        e = nil;
        ((void (*)(id, SEL, id))objc_msgSend)(PORT_LIB_CLASS(@"PKPassLibrary"),
            NSSelectorFromString(@"requestAutomaticPassPresentationSuppressionWithResponseHandler:"),
            ^(id token, NSError *error) {
                check(@"PKPassLibrary.requestAutomaticPass...: token", token == nil);
                e = error;
            });
        say(@"  ... its error", shape(e), @"PKPassKitErrorDomain/2");

        // -initWithIssuerData:signature:error: refuses, and the error out-param is the answer.
        NSError *issuerError = nil;
        // +1 from alloc, and the initialiser is a REFUSAL: it returns nil and the error, so the
        // allocation is still ours to release. That is the contract every initialiser has, and a
        // category over a class it does not own cannot change it.
        id raw = [papvc alloc];
        id controller = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)(
            raw, NSSelectorFromString(@"initWithIssuerData:signature:error:"), nil, nil, &issuerError);
        (void)raw;
        check(@"PKAddPassesViewController.initWithIssuerData: is nil", controller == nil);
        say(@"  ... its error", shape(issuerError), @"PKPassKitErrorDomain/2");

        // -initWithPasses: is NOT refused, and this is the case that says so.
        id built = ((id (*)(id, SEL, id))objc_msgSend)(
            [papvc alloc], NSSelectorFromString(@"initWithPasses:"), @[]);
        check(@"PKAddPassesViewController.initWithPasses: is built", built != nil);

        // The 26.0 pair, declared by NEITHER held SDK, so it is reached by its own selector. Its
        // answer is NotDetermined, and the case is here so a change to it shows in the transcript.
        say(@"PKPassLibrary.authorizationStatusForCapability:",
            [NSNumber numberWithInteger:((NSInteger (*)(id, SEL, NSInteger))objc_msgSend)(
                portLib(), NSSelectorFromString(@"authorizationStatusForCapability:"), 0)], @"-1");
        __block NSInteger requested = 1;
        e = nil;
        ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(portLib(),
            NSSelectorFromString(@"requestAuthorizationForCapability:completion:"), 0,
            ^(NSInteger status) { requested = status; });
        say(@"PKPassLibrary.requestAuthorizationForCapability: status",
            [NSNumber numberWithInteger:requested], @"-1");
        say(@"PKPassKitErrorDomain still linked after the 26.0 pair",
            [NSString stringWithFormat:@"%@", PKPassKitErrorDomain], @"PKPassKitErrorDomain");

        // The one thing the host IS the oracle for: the error domain must be the framework's own
        // bytes, so "linked, not defined" is measured and not asserted.
        say(@"PKPassKitErrorDomain", PKPassKitErrorDomain, @"PKPassKitErrorDomain");
        say(@"  ... its length", [NSNumber numberWithUnsignedInteger:[PKPassKitErrorDomain length]], @"20");
        check(@"PKPassKitErrorDomain is the host framework's own",
              [PKPassKitErrorDomain isEqualToString:@"PKPassKitErrorDomain"]);

        // THE FIVE VALUE CLASSES OF iOS 11, and the case that matters for each is again that the class
        // EXISTS. These five were `absent` with the Secure Element's reason until this band, and the
        // reason that reason was wrong is that they are the completion blocks' own value types: the
        // port already exports the two controllers whose delegate handlers take them.
        {
            Class result = PORT_CLASS(@"PKPaymentAuthorizationResult");
            Class update = PORT_CLASS(@"PKPaymentRequestUpdate");
            Class method = PORT_CLASS(@"PKPaymentRequestShippingMethodUpdate");
            Class paymentMethod = PORT_CLASS(@"PKPaymentRequestPaymentMethodUpdate");
            Class contact = PORT_CLASS(@"PKPaymentRequestShippingContactUpdate");
            for (NSString *name in @[@"PKPaymentAuthorizationResult", @"PKPaymentRequestUpdate",
                                     @"PKPaymentRequestShippingMethodUpdate",
                                     @"PKPaymentRequestPaymentMethodUpdate",
                                     @"PKPaymentRequestShippingContactUpdate"]) {
                check([@"the " stringByAppendingString:[name stringByAppendingString:@" class is carried"]],
                      PORT_CLASS(name) != Nil);
            }
            // The two roots descend from NSObject and the three updates from the port's own update
            // class, which is Apple's own chain as 11.0 measures it. A renamed class that got the
            // superclass wrong would answer every member below and still not be the class.
            check(@"  ... and the result descends from NSObject",
                  result != Nil && class_getSuperclass(result) == [NSObject class]);
            check(@"  ... and the update descends from NSObject",
                  update != Nil && class_getSuperclass(update) == [NSObject class]);
            for (Class c in @[method ?: [NSObject class], paymentMethod ?: [NSObject class],
                              contact ?: [NSObject class]]) {
                check([NSString stringWithFormat:@"  ... and %@ descends from the update",
                       NSStringFromClass(c)], c != Nil && class_getSuperclass(c) == update);
            }

            // The result: the status the delegate passed, and the errors in the order it passed them,
            // copied -- and the empty list rather than nil when there are none.
            __block id builtResult = nil;
            __block NSArray *readBack = nil;
            __block NSInteger readStatus = -99;
            NSError *first = [NSError errorWithDomain:@"probe.one" code:1 userInfo:nil];
            NSError *second = [NSError errorWithDomain:@"probe.two" code:2 userInfo:nil];
            NSMutableArray *passed = [NSMutableArray arrayWithObjects:first, second, nil];
            builtResult = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)([result alloc],
                NSSelectorFromString(@"initWithStatus:errors:"), 1, passed);
            readStatus = ((NSInteger (*)(id, SEL))objc_msgSend)(builtResult,
                NSSelectorFromString(@"status"));
            say(@"PKPaymentAuthorizationResult.status is what the delegate passed",
                [NSNumber numberWithInteger:readStatus], @"1");
            readBack = ((id (*)(id, SEL))objc_msgSend)(builtResult, NSSelectorFromString(@"errors"));
            check(@"  ... its errors are the two, in order",
                  [readBack isEqual:@[first, second]]);
            // The COPY, measured: mutating the array the delegate passed cannot change what the result
            // already reported. Without the copy this reads 1 instead of 2.
            [passed removeObjectAtIndex:0];
            readBack = ((id (*)(id, SEL))objc_msgSend)(builtResult, NSSelectorFromString(@"errors"));
            check(@"  ... and the copy is not the array the delegate mutated",
                  [readBack isEqual:@[first, second]]);
            builtResult = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)([result alloc],
                NSSelectorFromString(@"initWithStatus:errors:"), 1, nil);
            readBack = ((id (*)(id, SEL))objc_msgSend)(builtResult, NSSelectorFromString(@"errors"));
            check(@"  ... and null errors answer a list, not nil", readBack != nil);
            say(@"  ... whose count is a number and not a nil to test for",
                [NSNumber numberWithUnsignedInteger:[readBack count]], @"0");

            // The base update: status starts at Success, which is the enumeration's own zero, and the
            // summary items read back as given.
            __block id builtUpdate = nil;
            __block NSInteger updateStatus = -99;
            __block id items = nil;
            builtUpdate = ((id (*)(id, SEL, id))objc_msgSend)([update alloc],
                NSSelectorFromString(@"initWithPaymentSummaryItems:"), @[]);
            updateStatus = ((NSInteger (*)(id, SEL))objc_msgSend)(builtUpdate,
                NSSelectorFromString(@"status"));
            say(@"PKPaymentRequestUpdate.status defaults to Success", [NSNumber numberWithInteger:updateStatus], @"0");
            items = ((id (*)(id, SEL))objc_msgSend)(builtUpdate,
                NSSelectorFromString(@"paymentSummaryItems"));
            check(@"  ... its summary items are a list, not nil", items != nil);
            say(@"  ... whose count is what it was given",
                [NSNumber numberWithUnsignedInteger:[items count]], @"0");

            // The two updates with errors of their own, over the base's storage.
            for (NSString *name in @[@"PKPaymentRequestPaymentMethodUpdate",
                                     @"PKPaymentRequestShippingContactUpdate"]) {
                // @[first] and NOT first: `errors:` is an NSArray of errors, and passing the error
                // itself type-puns the declaration -- [NSError copy] answers the error rather than a
                // list of one, which is what an earlier run of this case measured.
                NSArray *arguments = [name isEqualToString:@"PKPaymentRequestShippingContactUpdate"]
                    ? @[@[first], @[], @[]] : @[@[first], @[]];
                NSString *initializer = [name isEqualToString:@"PKPaymentRequestShippingContactUpdate"]
                    ? @"initWithErrors:paymentSummaryItems:shippingMethods:" : @"initWithErrors:paymentSummaryItems:";
                Class c = PORT_CLASS(name);
                __block id instance = nil;
                __block id itsErrors = nil;
                // The initializer is spelled by hand rather than cast from a variadic type, so the
                // run does not depend on which arguments each one takes beyond the three and two the
                // SDK's header declares.
                if (arguments.count == 3) {
                    instance = ((id (*)(id, SEL, id, id, id))objc_msgSend)([c alloc],
                        NSSelectorFromString(initializer), arguments[0], arguments[1], arguments[2]);
                } else {
                    instance = ((id (*)(id, SEL, id, id))objc_msgSend)([c alloc],
                        NSSelectorFromString(initializer), arguments[0], arguments[1]);
                }
                itsErrors = ((id (*)(id, SEL))objc_msgSend)(instance, NSSelectorFromString(@"errors"));
                // What came back, and not only whether it matched: a transcript a reader reads has to
                // show the answer. The error's own DOMAIN is the part a caller can verify on a device
                // that has no PKPaymentRequest at all, since an NSError is one thing this release
                // does have.
                say([NSString stringWithFormat:@"%@ keeps the error it was given", name],
                    [NSString stringWithFormat:@"%lu of %@", (unsigned long)[itsErrors count],
                        [(NSError *)[itsErrors objectAtIndex:0] domain] ?: @"nil"],
                    @"1 of probe.one");
                updateStatus = ((NSInteger (*)(id, SEL))objc_msgSend)(instance,
                    NSSelectorFromString(@"status"));
                say([NSString stringWithFormat:@"  ... and %@ inherits Success for status", name],
                    [NSNumber numberWithInteger:updateStatus], @"0");
            }
            // The contact update's own shipping methods, which the base class has no member for.
            contact = PORT_CLASS(@"PKPaymentRequestShippingContactUpdate");
            id passedShipping = probeArg();
            id withMethods = ((id (*)(id, SEL, id, id, id))objc_msgSend)([contact alloc],
                NSSelectorFromString(@"initWithErrors:paymentSummaryItems:shippingMethods:"),
                nil, @[], @[passedShipping]);
            id methodsRead = ((id (*)(id, SEL))objc_msgSend)(withMethods,
                NSSelectorFromString(@"shippingMethods"));
            check(@"PKPaymentRequestShippingContactUpdate.shippingMethods is a list, not nil",
                  methodsRead != nil);
            say(@"  ... whose count is what it was given",
                [NSNumber numberWithUnsignedInteger:[methodsRead count]], @"1");
            // The list holds what was passed, and the pass was an NSString -- the point is that the
            // array is COPIED and handed back whole, and the only kind of object this release has to
            // put in a shipping-method list is one a caller already holds. So the case is IDENTITY --
            // the very object that went in comes back -- and not the concrete class of an NSString,
            // which is an implementation name a Foundation rename would turn red for a reason that
            // has nothing to do with the port.
            check(@"  ... and its one element is the very object that was passed",
                  [methodsRead objectAtIndex:0] == passedShipping);
            // The copy, measured the way the result's error list measures it: an NSMutableArray the
            // delegate empties afterwards cannot change what the update already reported.
            NSMutableArray *mutableMethods = [NSMutableArray arrayWithObject:probeArg()];
            id withMutable = ((id (*)(id, SEL, id, id, id))objc_msgSend)([contact alloc],
                NSSelectorFromString(@"initWithErrors:paymentSummaryItems:shippingMethods:"),
                nil, @[], mutableMethods);
            [mutableMethods removeAllObjects];
            say(@"  ... and the copy is not the array the delegate emptied",
                [NSNumber numberWithUnsignedInteger:[((id (*)(id, SEL))objc_msgSend)(withMutable,
                    NSSelectorFromString(@"shippingMethods")) count]], @"1");
            id withNullErrors = ((id (*)(id, SEL))objc_msgSend)(withMethods,
                NSSelectorFromString(@"errors"));
            check(@"  ... and null errors answer a list, not nil", withNullErrors != nil);
            say(@"  ... whose count is 0",
                [NSNumber numberWithUnsignedInteger:[withNullErrors count]], @"0");
            // The shipping-method update is the class alone, measured the way Apple's own 11.0 is: it
            // declares no member of its own, and it inherits the base's storage.
            method = PORT_CLASS(@"PKPaymentRequestShippingMethodUpdate");
            id builtMethod = ((id (*)(id, SEL, id))objc_msgSend)([method alloc],
                NSSelectorFromString(@"initWithPaymentSummaryItems:"), @[]);
            id methodItems = ((id (*)(id, SEL))objc_msgSend)(builtMethod,
                NSSelectorFromString(@"paymentSummaryItems"));
            check(@"PKPaymentRequestShippingMethodUpdate carries the base update's summary items",
                  methodItems != nil);
            say(@"  ... whose count is what it was given",
                [NSNumber numberWithUnsignedInteger:[methodItems count]], @"0");
            check(@"  ... and the class alone declares no instance selector of its own",
                  class_getInstanceMethod(method, NSSelectorFromString(@"shippingMethods")) ==
                      class_getInstanceMethod(update, NSSelectorFromString(@"shippingMethods")));

            // The 15.0 and 16.x properties are NOT this object's: @dynamic keeps them out, so the
            // class does not carry them. That is what makes this an 11.0 object and not a 16.4 one.
            check(@"PKPaymentRequestUpdate ships no shippingMethods of 15.0",
                  class_getInstanceMethod(update, NSSelectorFromString(@"shippingMethods")) == NULL);
            check(@"PKPaymentRequestUpdate ships no multiTokenContexts of 16.0",
                  class_getInstanceMethod(update, NSSelectorFromString(@"multiTokenContexts")) == NULL);
            check(@"PKPaymentAuthorizationResult ships no orderDetails of 16.0",
                  class_getInstanceMethod(result, NSSelectorFromString(@"orderDetails")) == NULL);
        }

        printf("# %lu check(s), %lu failure(s)\n", (unsigned long)gChecks, (unsigned long)gFailures);
        return gFailures == 0 ? 0 : 1;
    }
}
