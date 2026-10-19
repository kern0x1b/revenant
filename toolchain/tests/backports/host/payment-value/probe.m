#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <stdio.h>

static int failures = 0;

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

static NSString *orderValues(id order)
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@", show(get(order, @"orderTypeIdentifier")),
            show(get(order, @"orderIdentifier")), show(get(get(order, @"webServiceURL"), @"absoluteString")),
            show(get(order, @"authenticationToken"))];
}

static NSString *typeOf(id target)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)((NSUInteger (*)(id, SEL))objc_msgSend)(target,
            NSSelectorFromString(@"type"))];
}

static void setType(id target, NSUInteger type)
{
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(target, NSSelectorFromString(@"setType:"), type);
}

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

        NSArray *tokenGetters = @[@"paymentData", @"transactionIdentifier", @"paymentInstrumentName", @"paymentNetwork"];
        for (NSString *getter in tokenGetters) {
            id hostToken = make(@"PKPaymentToken", @"init", nil);
            id portToken = make(@"charonHost_PKPaymentToken", @"init", nil);
            report([@"fresh token " stringByAppendingString:getter], show(get(hostToken, getter)), show(get(portToken, getter)));
        }

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

        id hostPayment = make(@"PKPayment", @"initWithToken:", hostToken);
        id portPayment = make(@"charonHost_PKPayment", @"initWithToken:", portToken);
        report(@"payment token is the same object", [get(hostPayment, @"token") isEqual:hostToken] ? @"same" : @"other",
               [get(portPayment, @"token") isEqual:portToken] ? @"same" : @"other");

        id hostEmpty = make(@"PKPayment", @"init", nil);
        id portEmpty = make(@"charonHost_PKPayment", @"init", nil);
        report(@"empty payment token", show(get(hostEmpty, @"token")), show(get(portEmpty, @"token")));
        report(@"empty payment shippingMethod", show(get(hostEmpty, @"shippingMethod")), show(get(portEmpty, @"shippingMethod")));

        id hostShipping = [NSString stringWithFormat:@"method"];
        id portShipping = [NSString stringWithFormat:@"method"];
        set(hostEmpty, @"setShippingMethod:", hostShipping);
        set(portEmpty, @"setShippingMethod:", portShipping);
        report(@"payment shippingMethod is the object set", show(get(hostEmpty, @"shippingMethod")),
               show(get(portEmpty, @"shippingMethod")));

        NSData *hostPaymentArchive = [NSKeyedArchiver archivedDataWithRootObject:hostPayment requiringSecureCoding:YES error:NULL];
        NSData *portPaymentArchive = [NSKeyedArchiver archivedDataWithRootObject:portPayment requiringSecureCoding:YES error:NULL];
        id hostPaymentBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"PKPayment") fromData:hostPaymentArchive error:NULL];
        id portPaymentBack = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"charonHost_PKPayment") fromData:portPaymentArchive error:NULL];
        report(@"payment round trip keeps the token's identifier",
               show(get(get(hostPaymentBack, @"token"), @"transactionIdentifier")),
               show(get(get(portPaymentBack, @"token"), @"transactionIdentifier")));
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

        report(@"order archive keys and value classes", archiveFields(hostOrderArchive, @"PKPaymentOrderDetails"),
               archiveFields(portOrderArchive, @"PKPaymentOrderDetails"));
        report(@"port decodes the host's order archive", orderValues(decodeAs(hostOrderArchive, @"PKPaymentOrderDetails",
               @"charonHost_PKPaymentOrderDetails")), orderValues(hostOrder));
        report(@"host decodes the port's order archive", orderValues(decodeAs(portOrderArchive,
               @"charonHost_PKPaymentOrderDetails", @"PKPaymentOrderDetails")), orderValues(hostOrder));

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
