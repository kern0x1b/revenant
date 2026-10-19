// probe.m - PKPaymentToken and PKPayment, the port's against the host's PassKit, in one process.
//
// run.sh builds the port's PKPayment8.m with its two classes renamed (charonHost_PKPayment and
// charonHost_PKPaymentToken), so the system's PassKit keeps the real names. Each case is asked of both sides
// the same way, through the runtime: the host's header does not declare every selector the 8.0 surface has, and
// a message the header does not declare cannot be compiled, so every message here is sent by name. A case prints
// SAME when the two answers are equal, and FAIL when they are not; the process exits 1 on any FAIL.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <stdio.h>

static int failures = 0;

// Answers of a getter, sent by name: the object, or nil when the selector is not there.
static id get(id target, NSString *name)
{
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector])
        return @"(no selector)";
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static BOOL set(id target, NSString *name, id value)
{
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector])
        return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, value);
    return YES;
}

// The bare allocation of a class by name, nil when the release does not have the class.
static id allocate(NSString *className)
{
    Class cls = NSClassFromString(className);
    if (!cls)
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
}

static id make(NSString *className, NSString *initializer, id argument)
{
    id allocated = allocate(className);
    if (!argument)
        return ((id (*)(id, SEL))objc_msgSend)(allocated, NSSelectorFromString(initializer));
    return ((id (*)(id, SEL, id))objc_msgSend)(allocated, NSSelectorFromString(initializer), argument);
}

// The four-argument initializer of PKPaymentOrderDetails, sent by name as the others are.
static id make4(NSString *className, id first, id second, id third, id fourth)
{
    id allocated = allocate(className);
    return ((id (*)(id, SEL, id, id, id, id))objc_msgSend)(allocated,
        NSSelectorFromString(@"initWithOrderTypeIdentifier:orderIdentifier:webServiceURL:authenticationToken:"),
        first, second, third, fourth);
}

static void report(NSString *name, NSString *host, NSString *port)
{
    BOOL same = [host isEqualToString:port];
    if (!same)
        failures++;
    printf("%s %s host=%s port=%s\n", same ? "SAME" : "FAIL", name.UTF8String, host.UTF8String, port.UTF8String);
}

// An answer as a string a person can compare: the description of an object, "nil", or the "no selector" marker.
static NSString *show(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[NSString class]])
        return value;
    if ([value isKindOfClass:[NSData class]])
        return [NSString stringWithFormat:@"data(%lu)", (unsigned long)[value length]];
    return [NSString stringWithFormat:@"%@", NSStringFromClass([value class])];
}

// A keyed archive is a property list whose objects refer to one another by UID. The reader hands the UIDs back as
// CFKeyedArchiverUID objects, so the index is the number after "value = " in their description.
static BOOL isUIDRef(id value)
{
    return [[value description] hasPrefix:@"<CFKeyedArchiverUID"];
}

static NSUInteger uidValue(id value)
{
    NSString *text = [value description];
    NSRange range = [text rangeOfString:@"value = "];
    return [[text substringFromIndex:NSMaxRange(range)] integerValue];
}

// The fields a release archive of className carries, one "key:kind" per field, sorted. A kind is the class of the
// object the field refers to: NSString for a string, and the class name the archive stores for an object.
static NSString *archiveFields(NSData *data, NSString *className)
{
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    NSArray *objects = plist[@"$objects"];
    NSMutableArray *fields = [NSMutableArray array];
    for (id entry in objects) {
        if (![entry isKindOfClass:[NSDictionary class]] || !entry[@"$class"])
            continue;
        NSString *stored = objects[uidValue(entry[@"$class"])][@"$classname"];
        if (![stored hasSuffix:className])
            continue;
        for (NSString *key in [entry allKeys]) {
            if ([key isEqualToString:@"$class"])
                continue;
            id value = entry[key];
            NSString *kind = @"plain";
            if (isUIDRef(value)) {
                id target = objects[uidValue(value)];
                if ([target isKindOfClass:[NSString class]])
                    kind = @"NSString";
                else if ([target isKindOfClass:[NSDictionary class]] && target[@"$class"])
                    kind = objects[uidValue(target[@"$class"])][@"$classname"];
            }
            [fields addObject:[NSString stringWithFormat:@"%@:%@", key, kind]];
        }
    }
    return [[fields sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@" "];
}

// Decodes an archive whose root object is stored as storedName, with storedName read as the class target.
static id decodeAs(NSData *data, NSString *storedName, NSString *target)
{
    NSError *error = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    unarchiver.requiresSecureCoding = YES;
    [unarchiver setClass:NSClassFromString(target) forClassName:storedName];
    id object = [unarchiver decodeObjectOfClass:NSClassFromString(target) forKey:NSKeyedArchiveRootObjectKey];
    if (error)
        printf("  decode error: %s\n", error.description.UTF8String);
    return object;
}

// The four members of an order, as one line of text a person can compare.
static NSString *orderValues(id order)
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@", show(get(order, @"orderTypeIdentifier")),
            show(get(order, @"orderIdentifier")), show(get(get(order, @"webServiceURL"), @"absoluteString")),
            show(get(order, @"authenticationToken"))];
}

// The NSUInteger member, sent with its own signature (the generic getter would read it as an object).
static NSString *typeOf(id target)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)((NSUInteger (*)(id, SEL))objc_msgSend)(target,
            NSSelectorFromString(@"type"))];
}

static void setType(id target, NSUInteger type)
{
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(target, NSSelectorFromString(@"setType:"), type);
}

// The entries of an archiveFields string whose key is one of keys, in the same order.
static NSString *fieldsNamed(NSString *fields, NSArray *keys)
{
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *field in [fields componentsSeparatedByString:@" "]) {
        NSString *key = [[field componentsSeparatedByString:@":"] firstObject];
        if ([keys containsObject:key])
            [kept addObject:field];
    }
    return [kept componentsJoinedByString:@" "];
}

int main(void)
{
    @autoreleasepool {
        // The class exists on both sides and says it supports secure coding.
        for (NSString *cls in @[@"PKPaymentToken", @"PKPayment", @"PKPaymentOrderDetails", @"PKPaymentMethod"]) {
            NSString *host = NSClassFromString(cls) ? @"yes" : @"no";
            NSString *port = NSClassFromString([@"charonHost_" stringByAppendingString:cls]) ? @"yes" : @"no";
            report([cls stringByAppendingString:@" exists"], host, port);
        }
        for (NSString *cls in @[@"PKPaymentToken", @"PKPayment", @"PKPaymentOrderDetails", @"PKPaymentMethod"]) {
            NSString *host = [NSClassFromString(cls) respondsToSelector:@selector(supportsSecureCoding)]
                ? ([NSClassFromString(cls) supportsSecureCoding] ? @"yes" : @"no") : @"no";
            NSString *port = [NSClassFromString([@"charonHost_" stringByAppendingString:cls])
                respondsToSelector:@selector(supportsSecureCoding)]
                ? ([NSClassFromString([@"charonHost_" stringByAppendingString:cls]) supportsSecureCoding] ? @"yes" : @"no")
                : @"no";
            report([cls stringByAppendingString:@" supportsSecureCoding"], host, port);
        }

        // A fresh token answers nil in every member both sides have.
        NSArray *tokenGetters = @[@"paymentData", @"transactionIdentifier", @"paymentInstrumentName", @"paymentNetwork"];
        for (NSString *getter in tokenGetters) {
            id hostToken = make(@"PKPaymentToken", @"init", nil);
            id portToken = make(@"charonHost_PKPaymentToken", @"init", nil);
            report([@"fresh token " stringByAppendingString:getter], show(get(hostToken, getter)), show(get(portToken, getter)));
        }

        // The two members the host lets a caller set copy what they are given, so the caller's later change
        // does not reach the object.
        NSMutableData *hostData = [NSMutableData dataWithBytes:"abc" length:3];
        NSMutableData *portData = [NSMutableData dataWithBytes:"abc" length:3];
        id hostToken = make(@"PKPaymentToken", @"init", nil);
        id portToken = make(@"charonHost_PKPaymentToken", @"init", nil);
        set(hostToken, @"setPaymentData:", hostData);
        set(portToken, @"setPaymentData:", portData);
        hostData.length = 1;
        portData.length = 1;
        report(@"token paymentData copies what it is given", show(get(hostToken, @"paymentData")),
               show(get(portToken, @"paymentData")));

        NSMutableString *hostID = [NSMutableString stringWithString:@"id-1"];
        NSMutableString *portID = [NSMutableString stringWithString:@"id-1"];
        set(hostToken, @"setTransactionIdentifier:", hostID);
        set(portToken, @"setTransactionIdentifier:", portID);
        [hostID appendString:@"-changed"];
        [portID appendString:@"-changed"];
        report(@"token transactionIdentifier copies what it is given", show(get(hostToken, @"transactionIdentifier")),
               show(get(portToken, @"transactionIdentifier")));

        // A token that has been set round-trips through its own coder, with its two settable fields intact.
        NSData *hostArchive = [NSKeyedArchiver archivedDataWithRootObject:hostToken requiringSecureCoding:YES error:NULL];
        NSError *portArchiveError = nil;
        NSData *portArchive = [NSKeyedArchiver archivedDataWithRootObject:portToken requiringSecureCoding:YES error:&portArchiveError];
        if (!portArchive)
            printf("  port token archive error: %s\n", portArchiveError.description.UTF8String);
        id hostBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"PKPaymentToken") fromData:hostArchive error:NULL];
        NSError *portError = nil;
        id portBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"charonHost_PKPaymentToken") fromData:portArchive error:&portError];
        if (!portBack)
            printf("  port token unarchive error: %s\n", portError.description.UTF8String);
        report(@"token round trip keeps transactionIdentifier", show(get(hostBack, @"transactionIdentifier")),
               show(get(portBack, @"transactionIdentifier")));
        report(@"token round trip keeps paymentData", show(get(hostBack, @"paymentData")), show(get(portBack, @"paymentData")));

        // A payment keeps the token it was built with, and the same object comes back: not a copy.
        id hostPayment = make(@"PKPayment", @"initWithToken:", hostToken);
        id portPayment = make(@"charonHost_PKPayment", @"initWithToken:", portToken);
        report(@"payment token is the same object", [get(hostPayment, @"token") isEqual:hostToken] ? @"same" : @"other",
               [get(portPayment, @"token") isEqual:portToken] ? @"same" : @"other");

        // A payment built with plain -init has no token, and no shipping method.
        id hostEmpty = make(@"PKPayment", @"init", nil);
        id portEmpty = make(@"charonHost_PKPayment", @"init", nil);
        report(@"empty payment token", show(get(hostEmpty, @"token")), show(get(portEmpty, @"token")));
        report(@"empty payment shippingMethod", show(get(hostEmpty, @"shippingMethod")), show(get(portEmpty, @"shippingMethod")));

        // A payment's shipping method, when set, comes back as the object it was given.
        id hostShipping = [NSString stringWithFormat:@"method"];
        id portShipping = [NSString stringWithFormat:@"method"];
        set(hostEmpty, @"setShippingMethod:", hostShipping);
        set(portEmpty, @"setShippingMethod:", portShipping);
        report(@"payment shippingMethod is the object set", show(get(hostEmpty, @"shippingMethod")),
               show(get(portEmpty, @"shippingMethod")));

        // A payment round-trips its token through its own coder.
        NSData *hostPaymentArchive = [NSKeyedArchiver archivedDataWithRootObject:hostPayment requiringSecureCoding:YES error:NULL];
        NSData *portPaymentArchive = [NSKeyedArchiver archivedDataWithRootObject:portPayment requiringSecureCoding:YES error:NULL];
        id hostPaymentBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"PKPayment") fromData:hostPaymentArchive error:NULL];
        id portPaymentBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"charonHost_PKPayment") fromData:portPaymentArchive error:NULL];
        report(@"payment round trip keeps the token's identifier",
               show(get(get(hostPaymentBack, @"token"), @"transactionIdentifier")),
               show(get(get(portPaymentBack, @"token"), @"transactionIdentifier")));
        // PKPaymentOrderDetails: built with its four-argument initializer, the four members read back as given, a
        // plain init has none of them, a set value is a copy, and the object round-trips through its coder.
        NSURL *url = [NSURL URLWithString:@"https://example.com/w"];
        id hostOrder = make4(@"PKPaymentOrderDetails", @"type", @"order-1", url, @"token");
        id portOrder = make4(@"charonHost_PKPaymentOrderDetails", @"type", @"order-1", url, @"token");
        for (NSString *getter in @[@"orderTypeIdentifier", @"orderIdentifier", @"webServiceURL", @"authenticationToken"]) {
            report([@"order " stringByAppendingString:getter], show(get(hostOrder, getter)), show(get(portOrder, getter)));
        }
        id hostEmptyOrder = make(@"PKPaymentOrderDetails", @"init", nil);
        id portEmptyOrder = make(@"charonHost_PKPaymentOrderDetails", @"init", nil);
        report(@"fresh order identifier", show(get(hostEmptyOrder, @"orderIdentifier")),
               show(get(portEmptyOrder, @"orderIdentifier")));

        NSMutableString *hostIdentifier = [NSMutableString stringWithString:@"order-2"];
        NSMutableString *portIdentifier = [NSMutableString stringWithString:@"order-2"];
        set(hostOrder, @"setOrderIdentifier:", hostIdentifier);
        set(portOrder, @"setOrderIdentifier:", portIdentifier);
        [hostIdentifier appendString:@"-changed"];
        [portIdentifier appendString:@"-changed"];
        report(@"order identifier copies what it is given", show(get(hostOrder, @"orderIdentifier")),
               show(get(portOrder, @"orderIdentifier")));

        NSData *hostOrderArchive = [NSKeyedArchiver archivedDataWithRootObject:hostOrder requiringSecureCoding:YES error:NULL];
        NSData *portOrderArchive = [NSKeyedArchiver archivedDataWithRootObject:portOrder requiringSecureCoding:YES error:NULL];
        id hostOrderBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"PKPaymentOrderDetails") fromData:hostOrderArchive error:NULL];
        id portOrderBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"charonHost_PKPaymentOrderDetails") fromData:portOrderArchive error:NULL];
        report(@"order round trip keeps its identifier", show(get(hostOrderBack, @"orderIdentifier")),
               show(get(portOrderBack, @"orderIdentifier")));
        report(@"order round trip keeps its URL", show(get(get(hostOrderBack, @"webServiceURL"), @"absoluteString")),
               show(get(get(portOrderBack, @"webServiceURL"), @"absoluteString")));

        // The release's archive, in both directions. The host archives the order itself; the port's keys and value
        // classes must be the host's, and each side must read the other's archive back to the values it was given.
        report(@"order archive keys and value classes", archiveFields(hostOrderArchive, @"PKPaymentOrderDetails"),
               archiveFields(portOrderArchive, @"PKPaymentOrderDetails"));
        report(@"port decodes the host's order archive", orderValues(decodeAs(hostOrderArchive, @"PKPaymentOrderDetails",
               @"charonHost_PKPaymentOrderDetails")), orderValues(hostOrder));
        report(@"host decodes the port's order archive", orderValues(decodeAs(portOrderArchive,
               @"charonHost_PKPaymentOrderDetails", @"PKPaymentOrderDetails")), orderValues(hostOrder));

        // PKPaymentMethod, 9.0: a fresh method answers nil and 0; its members hold what they are given, and the strings are
        // copied; a method built from any pass is the empty one (the host answers that for a fresh pass); a copy has the same
        // members; the archive keeps the four members under their own names, and each side reads the other's back.
        id hostMethod = make(@"PKPaymentMethod", @"init", nil);
        id portMethod = make(@"charonHost_PKPaymentMethod", @"init", nil);
        report(@"fresh method type", typeOf(hostMethod), typeOf(portMethod));
        for (NSString *getter in @[@"displayName", @"network", @"paymentPass"]) {
            report([@"fresh method " stringByAppendingString:getter], show(get(hostMethod, getter)), show(get(portMethod, getter)));
        }

        NSMutableString *hostName = [NSMutableString stringWithString:@"Name"];
        NSMutableString *portName = [NSMutableString stringWithString:@"Name"];
        setType(hostMethod, 2);
        setType(portMethod, 2);
        set(hostMethod, @"setDisplayName:", hostName);
        set(portMethod, @"setDisplayName:", portName);
        [hostName appendString:@"-changed"];
        [portName appendString:@"-changed"];
        report(@"method type is the value set", typeOf(hostMethod), typeOf(portMethod));
        report(@"method displayName copies what it is given", show(get(hostMethod, @"displayName")),
               show(get(portMethod, @"displayName")));

        id pass = make(@"PKPaymentPass", @"init", nil);
        id hostFromPass = [NSClassFromString(@"PKPaymentMethod") alloc];
        hostFromPass = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(hostFromPass,
            NSSelectorFromString(@"initWithPaymentPass:obfuscateNetworks:"), pass, YES);
        id portFromPass = [NSClassFromString(@"charonHost_PKPaymentMethod") alloc];
        portFromPass = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(portFromPass,
            NSSelectorFromString(@"initWithPaymentPass:obfuscateNetworks:"), pass, YES);
        report(@"method from a fresh pass type", typeOf(hostFromPass), typeOf(portFromPass));
        report(@"method from a fresh pass network", show(get(hostFromPass, @"network")), show(get(portFromPass, @"network")));
        report(@"method from a fresh pass paymentPass", show(get(hostFromPass, @"paymentPass")),
               show(get(portFromPass, @"paymentPass")));

        id hostMethodCopy = [hostMethod copy];
        id portMethodCopy = [portMethod copy];
        report(@"method copy type", typeOf(hostMethodCopy), typeOf(portMethodCopy));
        report(@"method copy displayName", show(get(hostMethodCopy, @"displayName")), show(get(portMethodCopy, @"displayName")));

        NSData *hostMethodArchive = [NSKeyedArchiver archivedDataWithRootObject:hostMethod requiringSecureCoding:YES error:NULL];
        NSData *portMethodArchive = [NSKeyedArchiver archivedDataWithRootObject:portMethod requiringSecureCoding:YES error:NULL];
        NSArray *carried = @[@"type", @"displayName", @"network", @"paymentPass"];
        report(@"method archive keys and value classes", fieldsNamed(archiveFields(hostMethodArchive, @"PKPaymentMethod"), carried),
               fieldsNamed(archiveFields(portMethodArchive, @"PKPaymentMethod"), carried));
        id portFromHostMethod = decodeAs(hostMethodArchive, @"PKPaymentMethod", @"charonHost_PKPaymentMethod");
        id hostFromPortMethod = decodeAs(portMethodArchive, @"charonHost_PKPaymentMethod", @"PKPaymentMethod");
        report(@"port decodes the host's method archive", [NSString stringWithFormat:@"%@ %@", typeOf(portFromHostMethod),
               show(get(portFromHostMethod, @"displayName"))], [NSString stringWithFormat:@"%@ %@", typeOf(hostMethod),
               show(get(hostMethod, @"displayName"))]);
        report(@"host decodes the port's method archive", [NSString stringWithFormat:@"%@ %@", typeOf(hostFromPortMethod),
               show(get(hostFromPortMethod, @"displayName"))], [NSString stringWithFormat:@"%@ %@", typeOf(hostMethod),
               show(get(hostMethod, @"displayName"))]);
    }
    printf("failures=%d\n", failures);
    return failures ? 1 : 0;
}
