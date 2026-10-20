#import "RevenantWebKit.h"

@interface WKContentRuleList (RevenantContentRuleList)
- (instancetype)revenant_initWithIdentifier:(NSString *)identifier __attribute__((objc_method_family(init)));
@end

@implementation WKContentRuleList {
    NSString *_identifier;
}

- (instancetype)revenant_initWithIdentifier:(NSString *)identifier
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
    }
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>", NSStringFromClass([self class]), self,
            _identifier];
}

@end

#pragma mark - the compiler's own refusals

static NSError *revenant_rule_list_error(NSInteger code, NSString *sentence)
{
    NSString *help = [NSString stringWithFormat:@"Rule list %@: %@",
                                               code == WKErrorContentRuleListStoreCompileFailed
                                                   ? @"compilation failed"
                                                   : (code == WKErrorContentRuleListStoreLookUpFailed ? @"lookup failed" : @"removal failed"),
                                               sentence];
    return [NSError errorWithDomain:WKErrorDomain
                               code:code
                           userInfo:@{@"NSHelpAnchor": help, NSLocalizedDescriptionKey: help}];
}

static NSError *revenant_compile_refusal(NSString *sentence)
{
    return revenant_rule_list_error(WKErrorContentRuleListStoreCompileFailed, sentence);
}

static BOOL revenant_pattern_is_refused(NSString *pattern, BOOL in_a_domain_condition)
{
    NSUInteger length = pattern.length;
    NSInteger parens = 0;
    BOOL escaped = NO, in_class = NO, class_just_opened = NO, leading = YES;
    unichar previous = 0;
    NSMutableSet *group_names = [NSMutableSet set];
    for (NSUInteger index = 0; index < length; index++) {
        unichar c = [pattern characterAtIndex:index];
        if (escaped) {
            if (!in_class && (c == 'b' || c == 'B'))
                return YES;
            if (!in_class && c == 'k' && index + 1 < length && [pattern characterAtIndex:index + 1] == '<')
                return YES;
            escaped = NO;
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '\\') {
            escaped = YES;
            previous = c;
            continue;
        }
        if (in_class) {
            if (c == ']' && !class_just_opened)
                in_class = NO;
            class_just_opened = NO;
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '[') {
            in_class = YES;
            class_just_opened = index + 1 < length && [pattern characterAtIndex:index + 1] == '^';
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '|')
            return YES;
        if (c == '{' && index + 1 < length) {
            unichar next = [pattern characterAtIndex:index + 1];
            if (next >= '0' && next <= '9')
                return YES;
        }
        if (c == '(') {
            parens++;
            if (index + 1 < length && [pattern characterAtIndex:index + 1] == '?') {
                if (index + 2 >= length)
                    return YES;
                unichar next = [pattern characterAtIndex:index + 2];
                if (next == ':') {
                    index += 2;
                } else if (next == '<') {
                    NSUInteger close = index + 3;
                    while (close < length && [pattern characterAtIndex:close] != '>')
                        close++;
                    if (close >= length)
                        return YES;
                    if (index + 3 < length) {
                        unichar after = [pattern characterAtIndex:index + 3];
                        if (after == '=' || after == '!')
                            return YES;
                    }
                    NSString *name = [pattern substringWithRange:NSMakeRange(index + 3, close - index - 3)];
                    if ([group_names containsObject:name])
                        return YES;
                    [group_names addObject:name];
                    index = close;
                } else {
                    return YES;
                }
            }
            previous = c;
            leading = YES;
            continue;
        }
        if (c == ')') {
            if (--parens < 0)
                return YES;
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '*' || c == '+' || c == '?') {
            if (leading && !in_a_domain_condition)
                return YES;
            if ((c == '*' || c == '+') && (previous == '*' || previous == '+'))
                return YES;
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '^' || c == '$') {
            previous = c;
            continue;
        }
        previous = c;
        leading = NO;
    }
    return in_class || parens != 0 || escaped;
}

static NSString *revenant_resource_types(void)
{
    return @"document image style-sheet script font media svg-document raw popup ping csp-report other websocket";
}

static NSString *revenant_load_types(void)
{
    return @"first-party third-party";
}

static NSArray *revenant_array_under(NSDictionary *trigger, NSString *key)
{
    id value = trigger[key];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSError *revenant_rule_refusal(NSDictionary *rule)
{
    id triggerObject = rule[@"trigger"];
    if (![triggerObject isKindOfClass:[NSDictionary class]])
        return revenant_compile_refusal(@"Invalid trigger object.");
    NSDictionary *trigger = triggerObject;

    for (NSString *key in @[@"resource-type", @"load-type"]) {
        id values = trigger[key];
        if (!values)
            continue;
        if (![values isKindOfClass:[NSArray class]])
            return revenant_compile_refusal(@"Invalid trigger flags array.");
        NSString *known = [NSString stringWithFormat:@" %@ ",
                                     [key isEqualToString:@"load-type"] ? revenant_load_types() : revenant_resource_types()];
        for (id value in (NSArray *)values)
            if (![value isKindOfClass:[NSString class]] ||
                [known rangeOfString:[NSString stringWithFormat:@" %@ ", value]].location == NSNotFound)
                return revenant_compile_refusal(@"Invalid string in the trigger flags array.");
    }
    NSUInteger conditions = 0;
    for (NSString *key in @[@"if-domain", @"unless-domain"]) {
        if (!trigger[key])
            continue;
        conditions++;
        NSArray *values = revenant_array_under(trigger, key);
        if (!values || [values count] == 0)
            return revenant_compile_refusal(@"Invalid list of if-domain, unless-domain, if-top-url, or unless-top-url conditions.");
    }
    if (conditions > 1)
        return revenant_compile_refusal(@"A trigger cannot have more than one condition (if-domain, unless-domain, if-top-url, or unless-top-url)");

    id actionObject = rule[@"action"];
    if (![actionObject isKindOfClass:[NSDictionary class]])
        return revenant_compile_refusal(@"Invalid action object.");
    NSDictionary *action = actionObject;
    NSString *type = action[@"type"];
    NSArray *types = @[@"block", @"block-cookies", @"ignore-previous-rules", @"make-https",
                       @"css-display-none"];
    if (![type isKindOfClass:[NSString class]] || [types indexOfObject:type] == NSNotFound)
        return revenant_compile_refusal(@"Invalid action type.");
    if ([type isEqualToString:@"css-display-none"] && ![action[@"selector"] isKindOfClass:[NSString class]])
        return revenant_compile_refusal(@"Invalid css-display-none action type. Requires a selector.");

    id filter = trigger[@"url-filter"];
    if (![filter isKindOfClass:[NSString class]])
        return revenant_compile_refusal(@"Invalid url-filter object.");
    if (revenant_pattern_is_refused(filter, NO))
        return revenant_compile_refusal(@"Invalid or unsupported regular expression.");
    for (NSString *key in @[@"if-domain", @"unless-domain"])
        for (id domain in revenant_array_under(trigger, key))
            if (![domain isKindOfClass:[NSString class]] || revenant_pattern_is_refused(domain, YES))
                return revenant_compile_refusal(@"Invalid or unsupported regular expression.");
    return nil;
}

static NSError *revenant_compile(NSString *encoded)
{
    NSData *data = [encoded dataUsingEncoding:NSUTF8StringEncoding];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (!parsed)
        return revenant_compile_refusal(@"Failed to parse the JSON String.");
    if (![parsed isKindOfClass:[NSArray class]])
        return revenant_compile_refusal(@"Invalid input, the top level structure is not an array.");
    if ([(NSArray *)parsed count] == 0)
        return revenant_compile_refusal(@"Empty extension.");
    for (id rule in (NSArray *)parsed) {
        if (![rule isKindOfClass:[NSDictionary class]])
            return revenant_compile_refusal(@"Invalid rule.");
        NSError *refusal = revenant_rule_refusal(rule);
        if (refusal)
            return refusal;
    }
    return nil;
}

#pragma mark - the store

static NSString *revenant_store_file_name(void)
{
    return @"ContentRuleLists.json";
}

static NSArray *revenant_stored_lists(NSURL *url)
{
    NSData *data = [NSData dataWithContentsOfURL:[url URLByAppendingPathComponent:revenant_store_file_name()]];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [parsed isKindOfClass:[NSArray class]] ? parsed : @[];
}

static BOOL revenant_store_lists(NSArray *lists, NSURL *url)
{
    NSFileManager *files = [NSFileManager defaultManager];
    if (!url.path)
        return NO;
    if (![files createDirectoryAtPath:url.path withIntermediateDirectories:YES attributes:nil error:NULL] &&
        ![files fileExistsAtPath:url.path])
        return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:lists options:0 error:NULL];
    return data && [data writeToURL:[url URLByAppendingPathComponent:revenant_store_file_name()] atomically:YES];
}

static NSArray *revenant_pair_for_identifier(NSArray *lists, NSString *identifier)
{
    for (id pair in lists)
        if ([pair isKindOfClass:[NSArray class]] && [((NSArray *)pair).firstObject isEqual:identifier])
            return pair;
    return nil;
}

static void revenant_on_main_thread(void (^answer)(void))
{
    if ([NSThread isMainThread])
        answer();
    else
        dispatch_async(dispatch_get_main_queue(), answer);
}

@implementation WKContentRuleListStore {
    NSURL *_url;
}

+ (instancetype)defaultStore
{
    static WKContentRuleListStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *directories =
            NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *folder = [directories.firstObject ?: NSTemporaryDirectory()
            stringByAppendingPathComponent:@"ContentRuleLists"];
        store = [self storeWithURL:[NSURL fileURLWithPath:folder isDirectory:YES]];
    });
    return store;
}

+ (instancetype)storeWithURL:(NSURL *)url
{
    WKContentRuleListStore *store = [[self alloc] init];
    store->_url = [url copy];
    return store;
}

- (void)compileContentRuleListForIdentifier:(NSString *)identifier
                      encodedContentRuleList:(NSString *)encodedContentRuleList
                           completionHandler:(void (^)(WKContentRuleList *, NSError *))completionHandler
{
    NSError *refusal = revenant_compile(encodedContentRuleList);
    WKContentRuleList *list = nil;
    if (!refusal) {
        NSString *key = identifier ?: @"";
        NSMutableArray *updated = [revenant_stored_lists(_url) mutableCopy];
        NSArray *existing = revenant_pair_for_identifier(updated, key);
        NSUInteger at = existing ? [updated indexOfObject:existing] : NSNotFound;
        if (at == NSNotFound)
            [updated addObject:@[key, encodedContentRuleList]];
        else
            [updated replaceObjectAtIndex:at withObject:@[key, encodedContentRuleList]];
        if (revenant_store_lists(updated, _url))
            list = [[WKContentRuleList alloc] revenant_initWithIdentifier:key];
        else
            refusal = revenant_rule_list_error(WKErrorContentRuleListStoreCompileFailed,
                                             @"Unspecified error during compile.");
    }
    revenant_on_main_thread(^{
        if (completionHandler)
            completionHandler(list, refusal);
    });
}

- (void)lookUpContentRuleListForIdentifier:(NSString *)identifier
                          completionHandler:(void (^)(WKContentRuleList *, NSError *))completionHandler
{
    NSArray *pair = identifier ? revenant_pair_for_identifier(revenant_stored_lists(_url), identifier) : nil;
    NSError *refusal = pair ? nil
                            : revenant_rule_list_error(WKErrorContentRuleListStoreLookUpFailed,
                                                     @"Unspecified error during lookup.");
    WKContentRuleList *list = pair ? [[WKContentRuleList alloc] revenant_initWithIdentifier:identifier] : nil;
    revenant_on_main_thread(^{
        if (completionHandler)
            completionHandler(list, refusal);
    });
}

- (void)removeContentRuleListForIdentifier:(NSString *)identifier
                          completionHandler:(void (^)(NSError *))completionHandler
{
    NSMutableArray *kept = [revenant_stored_lists(_url) mutableCopy];
    NSUInteger at = identifier ? [kept indexOfObject:revenant_pair_for_identifier(kept, identifier) ?: [NSNull null]] : NSNotFound;
    NSError *refusal = nil;
    if (at == NSNotFound)
        refusal = revenant_rule_list_error(WKErrorContentRuleListStoreRemoveFailed,
                                         @"Unspecified error during remove.");
    else {
        [kept removeObjectAtIndex:at];
        if (!revenant_store_lists(kept, _url))
            refusal = revenant_rule_list_error(WKErrorContentRuleListStoreRemoveFailed,
                                             @"Unspecified error during remove.");
    }
    revenant_on_main_thread(^{
        if (completionHandler)
            completionHandler(refusal);
    });
}

- (void)getAvailableContentRuleListIdentifiers:(void (^)(NSArray<NSString *> *))completionHandler
{
    NSMutableArray *identifiers = [NSMutableArray array];
    for (NSArray *pair in revenant_stored_lists(_url))
        [identifiers addObject:pair.firstObject];
    revenant_on_main_thread(^{
        if (completionHandler)
            completionHandler(identifiers);
    });
}

@end
