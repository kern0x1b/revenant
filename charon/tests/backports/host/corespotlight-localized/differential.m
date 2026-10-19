#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>

static NSString *describe(id object)
{
    return object ? NSStringFromClass([object class]) : @"nil";
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        char line[512];
        while (fgets(line, sizeof line, stdin)) {
            NSString *given = [[NSString stringWithUTF8String:line] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSArray *keys = [given componentsSeparatedByString:@","];
            NSMutableArray *values = [NSMutableArray array];
            for (NSString *key in keys)
                [values addObject:[@"value " stringByAppendingString:key]];
            NSDictionary *strings = [NSDictionary dictionaryWithObjects:values forKeys:keys];
            NSArray *enumerated = [[strings keyEnumerator] allObjects];

            CSLocalizedString *localized = [[CSLocalizedString alloc] initWithLocalizedStrings:strings];
            NSString *answer = [localized localizedString];
            id copy = [localized copy];
            id mutable = [localized mutableCopy];
            NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:localized];
            id unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

            printf("keys=%s | enum=%s | answer=%s | length=%lu | class=%s | copy=%s | mutable=%s | unarchived=%s:%s | equal=%d\n",
                   [given UTF8String], [[enumerated componentsJoinedByString:@","] UTF8String],
                   answer ? [answer UTF8String] : "nil", (unsigned long)[localized length],
                   [describe(localized) UTF8String], [describe(copy) UTF8String], [describe(mutable) UTF8String],
                   [describe(unarchived) UTF8String], [unarchived isKindOfClass:[NSString class]] ? [[unarchived description] UTF8String] : "",
                   [localized isEqualToString:answer ?: @""]);
        }

        NSMutableDictionary *mutableStrings = [NSMutableDictionary dictionaryWithObjects:@[@"one", @"two"] forKeys:@[@"en_US", @"fr"]];
        CSLocalizedString *following = [[CSLocalizedString alloc] initWithLocalizedStrings:mutableStrings];
        NSString *before = [following localizedString];
        mutableStrings[@"en_US"] = @"changed";
        NSString *after = [following localizedString];
        printf("mutation: before=%s after=%s\n", [before UTF8String], [after UTF8String]);

        CSLocalizedString *empty = [[CSLocalizedString alloc] initWithLocalizedStrings:@{}];
        printf("empty: answer=%s length=%lu class=%s\n", [empty localizedString] ? "string" : "nil", (unsigned long)[empty length],
               describe(empty).UTF8String);
    }
    return 0;
}
