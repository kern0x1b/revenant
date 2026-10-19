#import <Foundation/Foundation.h>

BOOL charon_property_list_write(id value, NSURL *url, NSError **error);
id charon_property_list_read(NSURL *url, Class wanted, NSString *kind, NSError **error);

static NSString *charon_property_list_type(id value)
{
    CFStringRef name = CFCopyTypeIDDescription(CFGetTypeID((__bridge CFTypeRef)value));
    return (__bridge_transfer NSString *)name;
}

static NSString *charon_property_list_problem(id value)
{
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSData class]] || [value isKindOfClass:[NSDate class]]
        || [value isKindOfClass:[NSNumber class]])
        return nil;
    if ([value isKindOfClass:[NSArray class]]) {
        for (id item in value) {
            NSString *problem = charon_property_list_problem(item);
            if (problem)
                return problem;
        }
        return nil;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        for (id key in value) {
            if (![key isKindOfClass:[NSString class]])
                return [NSString stringWithFormat:@"property list dictionaries may only have keys which are CFStrings, not '%@'",
                                                  charon_property_list_type(key)];
            NSString *problem = charon_property_list_problem([value objectForKey:key]);
            if (problem)
                return problem;
        }
        return nil;
    }
    return [NSString stringWithFormat:@"property lists cannot contain objects of type '%@'", charon_property_list_type(value)];
}

BOOL charon_property_list_write(id value, NSURL *url, NSError **error)
{
    NSError *failure = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListXMLFormat_v1_0 options:0 error:&failure];
    if (!data) {
        if (!failure) {
            NSString *problem = charon_property_list_problem(value);
            NSDictionary *details = problem ? @{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"Property list invalid for format: %lu (%@)",
                                                                             (unsigned long)NSPropertyListXMLFormat_v1_0, problem]} : nil;
            failure = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListWriteStreamError userInfo:details];
        }
        if (error)
            *error = failure;
        return NO;
    }
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

id charon_property_list_read(NSURL *url, Class wanted, NSString *kind, NSError **error)
{
    if (!url)
        return nil;
    NSData *data = [[NSData alloc] initWithContentsOfURL:url options:0 error:error];
    if (!data)
        return nil;
    id value = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:error];
    if ([value isKindOfClass:wanted])
        return value;
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                                 userInfo:@{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"%@ did not contain a top-level %@ value", url, kind]}];
    return nil;
}
