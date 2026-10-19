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

static NSString *shape(NSError *error)
{
    if (!error) {
        return @"nil";
    }
    return [NSString stringWithFormat:@"%@/%ld", [error domain], (long)[error code]];
}

#define PORT_CLASS(name) NSClassFromString([@"charonHost_" stringByAppendingString:(name)])
#define PORT_LIB_CLASS(name) PORT_CLASS(name)

static id portLib(void)
{
    Class c = PORT_LIB_CLASS(@"PKPassLibrary");
    return c ? [[c alloc] init] : nil;
}

static id probeArg(void)
{
    return @"probe";
}

static BOOL classBool(Class c, NSString *sel)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(c, NSSelectorFromString(sel));
}

static BOOL instBool(NSString *sel)
{
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(portLib(), NSSelectorFromString(sel), @"x");
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        const char *dylib = getenv("CHARON_PORT_DYLIB");
        if (dylib) {
            dlopen(dylib, RTLD_LOCAL);
        }
        printf("# transcript: the PassKit Secure Element and wallet, one case per member\n");

        Class pac = PORT_CLASS(@"PKPaymentAuthorizationController");
        Class pavc = PORT_CLASS(@"PKPaymentAuthorizationViewController");
        Class papvc = PORT_CLASS(@"PKAddPassesViewController");

        {
            Class controller = PORT_CLASS(@"PKPaymentAuthorizationController");
            Class viewController = PORT_CLASS(@"PKPaymentAuthorizationViewController");
            check(@"the controller class is carried, not absent",
                  controller != Nil);
            check(@"  ... and its superclass is NSObject, the header's own",
                  controller != Nil && class_getSuperclass(controller) == [NSObject class]);
            check(@"the view controller class is carried, not absent", viewController != Nil);
            check(@"  ... and its superclass is UIViewController, the header's own",
                  viewController != Nil && class_getSuperclass(viewController) == [UIViewController class]);
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

        say(@"PKPassLibrary.presentSecureElementPass:",
            [NSNumber numberWithBool:((BOOL (*)(id, SEL, id))objc_msgSend)(
                portLib(), NSSelectorFromString(@"presentSecureElementPass:"), nil)], @"0");

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

        NSError *issuerError = nil;
        id raw = [papvc alloc];
        id controller = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)(
            raw, NSSelectorFromString(@"initWithIssuerData:signature:error:"), nil, nil, &issuerError);
        (void)raw;
        check(@"PKAddPassesViewController.initWithIssuerData: is nil", controller == nil);
        say(@"  ... its error", shape(issuerError), @"PKPassKitErrorDomain/2");

        id built = ((id (*)(id, SEL, id))objc_msgSend)(
            [papvc alloc], NSSelectorFromString(@"initWithPasses:"), @[]);
        check(@"PKAddPassesViewController.initWithPasses: is built", built != nil);

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

        say(@"PKPassKitErrorDomain", PKPassKitErrorDomain, @"PKPassKitErrorDomain");
        say(@"  ... its length", [NSNumber numberWithUnsignedInteger:[PKPassKitErrorDomain length]], @"20");
        check(@"PKPassKitErrorDomain is the host framework's own",
              [PKPassKitErrorDomain isEqualToString:@"PKPassKitErrorDomain"]);

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
            check(@"  ... and the result descends from NSObject",
                  result != Nil && class_getSuperclass(result) == [NSObject class]);
            check(@"  ... and the update descends from NSObject",
                  update != Nil && class_getSuperclass(update) == [NSObject class]);
            for (Class c in @[method ?: [NSObject class], paymentMethod ?: [NSObject class],
                              contact ?: [NSObject class]]) {
                check([NSString stringWithFormat:@"  ... and %@ descends from the update",
                       NSStringFromClass(c)], c != Nil && class_getSuperclass(c) == update);
            }

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

            for (NSString *name in @[@"PKPaymentRequestPaymentMethodUpdate",
                                     @"PKPaymentRequestShippingContactUpdate"]) {
                NSArray *arguments = [name isEqualToString:@"PKPaymentRequestShippingContactUpdate"]
                    ? @[@[first], @[], @[]] : @[@[first], @[]];
                NSString *initializer = [name isEqualToString:@"PKPaymentRequestShippingContactUpdate"]
                    ? @"initWithErrors:paymentSummaryItems:shippingMethods:" : @"initWithErrors:paymentSummaryItems:";
                Class c = PORT_CLASS(name);
                __block id instance = nil;
                __block id itsErrors = nil;
                if (arguments.count == 3) {
                    instance = ((id (*)(id, SEL, id, id, id))objc_msgSend)([c alloc],
                        NSSelectorFromString(initializer), arguments[0], arguments[1], arguments[2]);
                } else {
                    instance = ((id (*)(id, SEL, id, id))objc_msgSend)([c alloc],
                        NSSelectorFromString(initializer), arguments[0], arguments[1]);
                }
                itsErrors = ((id (*)(id, SEL))objc_msgSend)(instance, NSSelectorFromString(@"errors"));
                say([NSString stringWithFormat:@"%@ keeps the error it was given", name],
                    [NSString stringWithFormat:@"%lu of %@", (unsigned long)[itsErrors count],
                        [(NSError *)[itsErrors objectAtIndex:0] domain] ?: @"nil"],
                    @"1 of probe.one");
                updateStatus = ((NSInteger (*)(id, SEL))objc_msgSend)(instance,
                    NSSelectorFromString(@"status"));
                say([NSString stringWithFormat:@"  ... and %@ inherits Success for status", name],
                    [NSNumber numberWithInteger:updateStatus], @"0");
            }
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
            check(@"  ... and its one element is the very object that was passed",
                  [methodsRead objectAtIndex:0] == passedShipping);
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
