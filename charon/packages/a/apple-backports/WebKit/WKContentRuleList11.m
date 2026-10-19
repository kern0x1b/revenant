#import "CharonWebKit.h"

/* WKContentRuleList and WKContentRuleListStore: the store a content blocker is compiled into, as it
 * is of iOS 11.0. The 16.4 SDK this package compiles against declares both classes, so nothing here is
 * transcribed; what is below is what the release answers, measured on this machine by asking the
 * host's own WebKit, and the measurements are in facts/WebKit/WKContentRuleList.md.
 *
 * WHAT A COMPILE IS. A validation and a store: the release parses the JSON, refuses a list it cannot
 * use, and otherwise hands back a WKContentRuleList carrying the identifier it was compiled under.
 * Every refusal is WKErrorDomain with WKErrorContentRuleListStoreCompileFailed, and the reason is in
 * the error's NSHelpAnchor, which the port writes with the host's own sentence. WHICH of two bad
 * things in one rule is reported was measured too, and it is not the order the keys are read in: the
 * trigger's shape, then its flag arrays, then the action's shape and type, and only then the
 * url-filter and the domain patterns. A rule with a bad action and a bad url-filter reports the
 * action.
 *
 * WHAT THE PORT CANNOT DO. A compiled list is applied by a web view's content blocker, and this port
 * has no web view, so nothing here ever matches a request: the rules are validated and kept, and no
 * rule of them is ever run. What the store owes a caller -- that a list survives the process, that a
 * second store over the same url sees it, that removing one takes it out -- the port does.
 *
 * THE STORE ON DISK. The release keeps a directory at the url with a file per compiled list in it
 * (measured: the url is a directory holding one file per list, some named after the identifier and
 * some not). That naming is Apple's and not an API, so the port keeps the same shape and its own
 * file: one directory at the url, and inside it one file holding every identifier with the list
 * stored under it. What the API promises -- a list written in one process is there in the next --
 * holds either way.
 *
 * THE ORDER getAvailableContentRuleListIdentifiers ANSWERS IS NOT PART OF THE API. The release answers
 * whatever order its directory hands over, which is neither the order they were stored in nor sorted
 * (measured over fifteen lists stored in one order and read back in another), so the port answers the
 * order it stored them in, which is at least deterministic, and the differential sorts both sides
 * before comparing them.
 */

@interface WKContentRuleList (CharonContentRuleList)
- (instancetype)charon_initWithIdentifier:(NSString *)identifier __attribute__((objc_method_family(init)));
@end

@implementation WKContentRuleList {
    NSString *_identifier;
}

/* The release's own list is built by its store and there is no public way to build one, so the port's
 * initialiser is charon_-prefixed for the same reason WKWebExtension's is. */
- (instancetype)charon_initWithIdentifier:(NSString *)identifier
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

/* The host's error carries its reason under NSHelpAnchor and nothing else, and the reason is a fixed
 * sentence per failure: "Rule list compilation failed: Invalid action type." The port writes the same
 * sentence, because it is the one a caller reads. */
static NSError *charon_rule_list_error(NSInteger code, NSString *sentence)
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

static NSError *charon_compile_refusal(NSString *sentence)
{
    return charon_rule_list_error(WKErrorContentRuleListStoreCompileFailed, sentence);
}

/* The url-filter grammar is YARR's and not ICU's: a rule list is matched against every request a web
 * view loads, so the release compiles the pattern once into its own engine and refuses everything that
 * engine does not implement. Measured construct by construct on the host:
 *
 *   refused: an unescaped | ("Disjunctions are not supported yet"), (?=, (?!, (?<= and (?<! (the
 *   lookaround assertions), a {2} or a {2,3} counted repetition, a (?i) or (?P<name> or (?'name'
 *   group, \b and \B ("Word boundaries assertions are not supported yet"), a \k<name> backreference
 *   ("Patterns cannot contain backreferences"), and every pattern ICU itself will not compile: an
 *   unbalanced ( or [, a leading * or ?, a doubled quantifier, a stray ).
 *   accepted: literals, a dot, character classes with POSIX classes inside them, ^ and $, + * ? and
 *   their lazy forms, groups, (?:...) and (?<name>...), escaped metacharacters (\| \( \) \{ \} \.),
 *   a numeric backreference, an unpaired { and a lone ].
 *
 * So the port reads the pattern itself, and refuses the six constructs above, a quantifier with nothing
 * in front of it, a class or a group left open, and two groups with one name. NSRegularExpression is
 * NOT the test: it refuses a{ and *example.com, which YARR accepts in a domain condition, and accepts
 * a{2} where YARR refuses, so it would have been wrong in both directions.
 *
 * A construct of YARR's grammar that no probe here reached is answered by these rules rather than by a
 * measurement, and the facts page names the ones that were reached: fifty patterns, asked one at a time.
 */
static BOOL charon_pattern_is_refused(NSString *pattern, BOOL in_a_domain_condition)
{
    NSUInteger length = pattern.length;
    NSInteger parens = 0;
    BOOL escaped = NO, in_class = NO, class_just_opened = NO, leading = YES;
    unichar previous = 0;
    NSMutableSet *group_names = [NSMutableSet set];
    for (NSUInteger index = 0; index < length; index++) {
        unichar c = [pattern characterAtIndex:index];
        if (escaped) {
            /* \b and \B are the boundary assertions and \k<name> is the named backreference; every other
             * escape is a literal or a class YARR keeps, including \Q...\E and \p{L}. */
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
            /* a ] straight after [ or [^ is the class's own first character and not its end */
            if (c == ']' && !class_just_opened)
                in_class = NO;
            class_just_opened = NO;
            previous = c;
            leading = NO;
            continue;
        }
        if (c == '[') {
            /* [] is an empty class and closes at once; a ] straight after a [^ is that class's own
             * first character and does not close it (measured: []x, []]x and [^]a] are all accepted). */
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
                    /* (?<= and (?<! are lookbehinds; (?<name> is a group, and two groups may not share a
                     * name. */
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
            /* A quantifier with nothing in front of it: the release's own parser calls that an internal
             * error, and refuses it in a url-filter while accepting it in a domain condition (measured
             * both ways, so the two are not the same check). */
            if (leading && !in_a_domain_condition)
                return YES;
            /* Two quantifiers in a row where the second is not the lazy form: a** is refused and the
             * lazy a+? and a*? are accepted (measured both). */
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
    /* a class or a group left open is a pattern the release cannot compile */
    return in_class || parens != 0 || escaped;
}

/* The trigger's flag arrays name a resource type or a load type by string. The sets are the ones a
 * rule list of this release is written against; the host knows four more (webtransport, webbundle,
 * manifest and xslt, all later additions to Safari's list) and refuses every one of them with this
 * same sentence, so a rule naming one is refused here as a name this port's list has not heard of.
 */
static NSString *charon_resource_types(void)
{
    return @"document image style-sheet script font media svg-document raw popup ping csp-report other websocket";
}

static NSString *charon_load_types(void)
{
    return @"first-party third-party";
}

static NSArray *charon_array_under(NSDictionary *trigger, NSString *key)
{
    id value = trigger[key];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

/* nil for a rule this port can use, and the host's own sentence for one it cannot, checked in the
 * order the host reports in. */
static NSError *charon_rule_refusal(NSDictionary *rule)
{
    id triggerObject = rule[@"trigger"];
    if (![triggerObject isKindOfClass:[NSDictionary class]])
        return charon_compile_refusal(@"Invalid trigger object.");
    NSDictionary *trigger = triggerObject;

    for (NSString *key in @[@"resource-type", @"load-type"]) {
        id values = trigger[key];
        if (!values)
            continue;
        if (![values isKindOfClass:[NSArray class]])
            return charon_compile_refusal(@"Invalid trigger flags array.");
        /* the names are searched for as " name " so that a value which is a PREFIX of a name does not
         * match it: "font" must not be found inside "font-something" */
        NSString *known = [NSString stringWithFormat:@" %@ ",
                                     [key isEqualToString:@"load-type"] ? charon_load_types() : charon_resource_types()];
        for (id value in (NSArray *)values)
            if (![value isKindOfClass:[NSString class]] ||
                [known rangeOfString:[NSString stringWithFormat:@" %@ ", value]].location == NSNotFound)
                return charon_compile_refusal(@"Invalid string in the trigger flags array.");
    }
    /* At most ONE domain condition per trigger: a trigger carrying both if-domain and unless-domain is
     * refused, and the host names four keys where this port knows two (measured). An EMPTY domain list is
     * refused and an empty resource-type list is not: measured both. */
    NSUInteger conditions = 0;
    for (NSString *key in @[@"if-domain", @"unless-domain"]) {
        if (!trigger[key])
            continue;
        conditions++;
        NSArray *values = charon_array_under(trigger, key);
        if (!values || [values count] == 0)
            return charon_compile_refusal(@"Invalid list of if-domain, unless-domain, if-top-url, or unless-top-url conditions.");
    }
    if (conditions > 1)
        return charon_compile_refusal(@"A trigger cannot have more than one condition (if-domain, unless-domain, if-top-url, or unless-top-url)");

    id actionObject = rule[@"action"];
    if (![actionObject isKindOfClass:[NSDictionary class]])
        return charon_compile_refusal(@"Invalid action object.");
    NSDictionary *action = actionObject;
    NSString *type = action[@"type"];
    NSArray *types = @[@"block", @"block-cookies", @"ignore-previous-rules", @"make-https",
                       @"css-display-none"];
    if (![type isKindOfClass:[NSString class]] || [types indexOfObject:type] == NSNotFound)
        return charon_compile_refusal(@"Invalid action type.");
    if ([type isEqualToString:@"css-display-none"] && ![action[@"selector"] isKindOfClass:[NSString class]])
        return charon_compile_refusal(@"Invalid css-display-none action type. Requires a selector.");

    id filter = trigger[@"url-filter"];
    if (![filter isKindOfClass:[NSString class]])
        return charon_compile_refusal(@"Invalid url-filter object.");
    if (charon_pattern_is_refused(filter, NO))
        return charon_compile_refusal(@"Invalid or unsupported regular expression.");
    for (NSString *key in @[@"if-domain", @"unless-domain"])
        for (id domain in charon_array_under(trigger, key))
            if (![domain isKindOfClass:[NSString class]] || charon_pattern_is_refused(domain, YES))
                return charon_compile_refusal(@"Invalid or unsupported regular expression.");
    return nil;
}

static NSError *charon_compile(NSString *encoded)
{
    NSData *data = [encoded dataUsingEncoding:NSUTF8StringEncoding];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (!parsed)
        return charon_compile_refusal(@"Failed to parse the JSON String.");
    if (![parsed isKindOfClass:[NSArray class]])
        return charon_compile_refusal(@"Invalid input, the top level structure is not an array.");
    if ([(NSArray *)parsed count] == 0)
        return charon_compile_refusal(@"Empty extension.");
    for (id rule in (NSArray *)parsed) {
        if (![rule isKindOfClass:[NSDictionary class]])
            return charon_compile_refusal(@"Invalid rule.");
        NSError *refusal = charon_rule_refusal(rule);
        if (refusal)
            return refusal;
    }
    return nil;
}

#pragma mark - the store

/* The file inside the store's directory: pairs of an identifier and the list stored under it, in the
 * order they were first stored. An array of pairs and not a dictionary, because the order the release
 * answers is its directory's and the port's own order is the one it stored. */
static NSString *charon_store_file_name(void)
{
    return @"ContentRuleLists.json";
}

static NSArray *charon_stored_lists(NSURL *url)
{
    NSData *data = [NSData dataWithContentsOfURL:[url URLByAppendingPathComponent:charon_store_file_name()]];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [parsed isKindOfClass:[NSArray class]] ? parsed : @[];
}

static BOOL charon_store_lists(NSArray *lists, NSURL *url)
{
    NSFileManager *files = [NSFileManager defaultManager];
    if (!url.path)
        return NO;
    if (![files createDirectoryAtPath:url.path withIntermediateDirectories:YES attributes:nil error:NULL] &&
        ![files fileExistsAtPath:url.path])
        return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:lists options:0 error:NULL];
    return data && [data writeToURL:[url URLByAppendingPathComponent:charon_store_file_name()] atomically:YES];
}

static NSArray *charon_pair_for_identifier(NSArray *lists, NSString *identifier)
{
    for (id pair in lists)
        if ([pair isKindOfClass:[NSArray class]] && [((NSArray *)pair).firstObject isEqual:identifier])
            return pair;
    return nil;
}

/* Every answer below is delivered on the main thread, which is what the host does whether the call
 * came from the main thread or from another one (measured both ways). Whether it is delivered before
 * the call returns is NOT part of the API and is not consistent in the host either -- its cheap
 * refusals answer inside the call and its expensive ones answer from the run loop -- so the port
 * answers inside the call when it is already on the main thread and hops to it when it is not. */
static void charon_on_main_thread(void (^answer)(void))
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
        /* Application Support is not a directory on the 4.3 band this library also builds for, and the
         * store is still a store there: HomeKit's own store falls back the same way. */
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
    /* An empty identifier is an identifier, and so is none at all: the release compiles under both and
     * hands back a list whose own identifier is the empty string (measured). A refused list leaves the
     * store as it was, which is the host's own answer for an identifier that was stored before and is
     * asked to compile something unusable after. */
    NSError *refusal = charon_compile(encodedContentRuleList);
    WKContentRuleList *list = nil;
    if (!refusal) {
        NSString *key = identifier ?: @"";
        NSMutableArray *updated = [charon_stored_lists(_url) mutableCopy];
        NSArray *existing = charon_pair_for_identifier(updated, key);
        NSUInteger at = existing ? [updated indexOfObject:existing] : NSNotFound;
        if (at == NSNotFound)
            [updated addObject:@[key, encodedContentRuleList]];
        else
            [updated replaceObjectAtIndex:at withObject:@[key, encodedContentRuleList]];
        if (charon_store_lists(updated, _url))
            list = [[WKContentRuleList alloc] charon_initWithIdentifier:key];
        else
            /* the store could not be written -- measured against the host with a REGULAR FILE where the
             * store wants a directory, which is the one way to make it refuse that a program can arrange:
             * it answers this sentence and not one of the list's own */
            refusal = charon_rule_list_error(WKErrorContentRuleListStoreCompileFailed,
                                             @"Unspecified error during compile.");
    }
    charon_on_main_thread(^{
        if (completionHandler)
            completionHandler(list, refusal);
    });
}

- (void)lookUpContentRuleListForIdentifier:(NSString *)identifier
                          completionHandler:(void (^)(WKContentRuleList *, NSError *))completionHandler
{
    NSArray *pair = identifier ? charon_pair_for_identifier(charon_stored_lists(_url), identifier) : nil;
    /* Nothing stored under that identifier and no identifier at all are the same answer: nil and a
     * look-up failure, for both (measured). */
    NSError *refusal = pair ? nil
                            : charon_rule_list_error(WKErrorContentRuleListStoreLookUpFailed,
                                                     @"Unspecified error during lookup.");
    WKContentRuleList *list = pair ? [[WKContentRuleList alloc] charon_initWithIdentifier:identifier] : nil;
    charon_on_main_thread(^{
        if (completionHandler)
            completionHandler(list, refusal);
    });
}

- (void)removeContentRuleListForIdentifier:(NSString *)identifier
                          completionHandler:(void (^)(NSError *))completionHandler
{
    NSMutableArray *kept = [charon_stored_lists(_url) mutableCopy];
    NSUInteger at = identifier ? [kept indexOfObject:charon_pair_for_identifier(kept, identifier) ?: [NSNull null]] : NSNotFound;
    NSError *refusal = nil;
    if (at == NSNotFound)
        refusal = charon_rule_list_error(WKErrorContentRuleListStoreRemoveFailed,
                                         @"Unspecified error during remove.");
    else {
        [kept removeObjectAtIndex:at];
        if (!charon_store_lists(kept, _url))
            /* the list is out of the store and the store could not be written, so the caller is told
             * and the next answer about it is that it is not there */
            refusal = charon_rule_list_error(WKErrorContentRuleListStoreRemoveFailed,
                                             @"Unspecified error during remove.");
    }
    charon_on_main_thread(^{
        if (completionHandler)
            completionHandler(refusal);
    });
}

- (void)getAvailableContentRuleListIdentifiers:(void (^)(NSArray<NSString *> *))completionHandler
{
    NSMutableArray *identifiers = [NSMutableArray array];
    for (NSArray *pair in charon_stored_lists(_url))
        [identifiers addObject:pair.firstObject];
    charon_on_main_thread(^{
        if (completionHandler)
            completionHandler(identifiers);
    });
}

@end