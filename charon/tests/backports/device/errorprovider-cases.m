#import "errorprovider-cases.h"

static NSString *show(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[NSArray class]])
        return [(NSArray *)value componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@", value];
}

void errorprovider_run(Class error_class, ErrorProviderSetter set_provider, ErrorProviderRecorder record)
{
    NSMutableArray *asked = [NSMutableArray array];
    NSString *domain = @"charon.provider";
    NSError *(^plain)(void) = ^NSError *{ return [error_class errorWithDomain:domain code:7 userInfo:nil]; };
    record(@"no provider description", show(plain().localizedDescription));
    record(@"no provider reason", show(plain().localizedFailureReason));
    set_provider(error_class, domain, ^id(NSError *error, NSErrorUserInfoKey key) {
        [asked addObject:key];
        if ([key isEqualToString:NSLocalizedDescriptionKey])
            return [NSString stringWithFormat:@"description of %ld", (long)error.code];
        if ([key isEqualToString:NSLocalizedFailureReasonErrorKey])
            return @"a reason";
        if ([key isEqualToString:NSLocalizedRecoverySuggestionErrorKey])
            return @"a suggestion";
        if ([key isEqualToString:NSLocalizedRecoveryOptionsErrorKey])
            return @[@"Retry", @"Cancel"];
        if ([key isEqualToString:NSHelpAnchorErrorKey])
            return @"an anchor";
        return nil;
    });
    NSError *error = plain();
    NSArray *getters = @[@"localizedDescription", @"localizedFailureReason", @"localizedRecoverySuggestion", @"localizedRecoveryOptions", @"recoveryAttempter", @"helpAnchor"];
    for (NSString *getter in getters) {
        [asked removeAllObjects];
        id value = [error valueForKey:getter];
        record([@"provider " stringByAppendingString:getter], [NSString stringWithFormat:@"%@ | asked %@", show(value), [asked componentsJoinedByString:@","]]);
    }
    [asked removeAllObjects];
    NSDictionary *info = error.userInfo;
    record(@"user info stays empty", [NSString stringWithFormat:@"%lu | asked %@", (unsigned long)info.count, [asked componentsJoinedByString:@","]]);
    [asked removeAllObjects];
    id direct = error.userInfo[NSLocalizedDescriptionKey];
    record(@"user info lookup", [NSString stringWithFormat:@"%@ | asked %@", show(direct), [asked componentsJoinedByString:@","]]);
    record(@"description text", [show(error.description) rangeOfString:@"description of 7"].location != NSNotFound ? @"uses the provider" : show(error.description));
    [asked removeAllObjects];
    NSError *given = [error_class errorWithDomain:domain code:8 userInfo:@{NSLocalizedDescriptionKey: @"given", NSLocalizedFailureReasonErrorKey: @"given reason"}];
    record(@"user info wins", [NSString stringWithFormat:@"%@ / %@ | asked %@", given.localizedDescription, given.localizedFailureReason, [asked componentsJoinedByString:@","]]);
    NSError *other = [error_class errorWithDomain:@"charon.other" code:7 userInfo:nil];
    [asked removeAllObjects];
    record(@"other domain", [NSString stringWithFormat:@"%@ | asked %lu", show(other.localizedDescription), (unsigned long)asked.count]);
    NSError *reasoned = [error_class errorWithDomain:domain code:9 userInfo:@{NSLocalizedFailureReasonErrorKey: @"only a reason"}];
    record(@"reason in user info, description from provider", show(reasoned.localizedDescription));
    set_provider(error_class, domain, ^id(NSError *error, NSErrorUserInfoKey key) {
        return [key isEqualToString:NSLocalizedFailureReasonErrorKey] ? @"second" : nil;
    });
    record(@"replaced provider", [NSString stringWithFormat:@"%@ / %@", show(plain().localizedFailureReason), show(plain().localizedDescription)]);
    set_provider(error_class, domain, nil);
    record(@"removed provider", [NSString stringWithFormat:@"%@ / %@", show(plain().localizedFailureReason), show(plain().localizedDescription)]);
    set_provider(error_class, @"charon.retained", ^id(NSError *error, NSErrorUserInfoKey key) {
        return [key isEqualToString:NSLocalizedDescriptionKey] ? [NSString stringWithFormat:@"%@:%ld", error.domain, (long)error.code] : nil;
    });
    NSError *retained = [error_class errorWithDomain:@"charon.retained" code:3 userInfo:nil];
    NSError *copy = [retained copy];
    record(@"copied error", show(copy.localizedDescription));
    record(@"retained domain", show(retained.localizedDescription));
    NSError *underlying = [error_class errorWithDomain:@"charon.outer" code:1 userInfo:@{NSUnderlyingErrorKey: retained}];
    record(@"underlying not consulted", show(underlying.localizedDescription));
}
