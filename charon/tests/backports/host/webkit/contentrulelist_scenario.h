/* The questions both sides are asked about the content rule list store, in one place, so the system's
 * WebKit and the port's cannot be asked different ones. Compiled TWICE by run.sh: once plain, with no
 * port code in the process, where the names below are Apple's; and once with renames.sh's -D flags,
 * where the very same names are the port's. Each side answers the same list in the same order and the
 * test compares them line by line with ur_agree.
 *
 * What is compared per case is a LIST OR NO LIST, the error's DOMAIN and CODE, and the sentence under
 * NSHelpAnchor. The first two are the API; the third is in the comparison because the API does not
 * separate the failures: an action type that does not exist, a url-filter with a disjunction and a
 * url-filter with a counted repetition are all WKErrorContentRuleListStoreCompileFailed, and the
 * sentence is the only thing that tells them apart. The sentences are Apple's, compared verbatim, so
 * a WebKit that rewords one turns this comparison red rather than quietly agreeing on less.
 *
 * THE STORE IS EMPTIED FIRST, and both sides are given the SAME url, so the two runs start from the
 * same state. run.sh then runs the system side and the port side against that one url in that order,
 * so a list the system stores is still there when the port is asked: that is what makes the store's
 * persistence across processes something this comparison holds rather than something it assumes.
 *
 * THE ORDER the identifiers come back in is NOT compared, and deliberately: the release answers its
 * directory's order, which is neither the order the lists were stored in nor sorted (measured over
 * fifteen lists), so each side's list is sorted before it is written down. The count is compared.
 */
#import "../uikit2/uirest.h"
/* The SDK's own WebKit, and NOT the port's headers: in the system build these are Apple's declarations,
 * and in the port build renames.sh's -D flags make the same declarations name the port's classes. */
#import <WebKit/WebKit.h>

/* One store, one url, both sides. Nothing here builds a path of its own, because two sides building two
 * paths would be two different stores and the comparison would be of two different questions. */
static NSURL *rule_store(void)
{
    const char *given = getenv("CHARON_RULE_STORE");
    NSString *path = given ? @(given) : [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-rule-store"];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

/* A store over a path a REGULAR FILE occupies, which is the one way a program can make a store refuse
 * that this measurement reaches: the release wants a directory at the url and answers its own sentence
 * when it finds a file there. Both sides are given the same path and the file is written by both, so
 * neither side is answering about a state the other did not see. */
static NSURL *blocked_rule_store(void)
{
    /* BESIDE the store's directory, not inside it: the test below counts what is inside, and a second
     * entry there would be this file rather than the store's own */
    return [rule_store().URLByDeletingLastPathComponent URLByAppendingPathComponent:@"blocked.store"];
}

/* A fresh store on both sides: the directory and everything under it go, so the first case answers for
 * an empty store whatever ran before. */
static void rule_store_reset(void)
{
    NSFileManager *files = [NSFileManager defaultManager];
    [files removeItemAtURL:rule_store() error:NULL];
    NSURL *blocked = blocked_rule_store();
    [files removeItemAtURL:blocked error:NULL];
    [files createDirectoryAtPath:blocked.URLByDeletingLastPathComponent.path withIntermediateDirectories:YES
      attributes:nil error:NULL];
    [@"not a directory" writeToURL:blocked atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

/* A store's own answer, in the one shape the comparison reads: what came back, and the error whole. */
static NSString *rule_answer(WKContentRuleList *list, NSError *error)
{
    NSString *found = list ? [NSString stringWithFormat:@"list %@", list.identifier] : @"nil";
    if (!error)
        return [NSString stringWithFormat:@"%@ | no error", found];
    return [NSString stringWithFormat:@"%@ | %@ %ld | %@", found, error.domain, (long)error.code,
                                      error.userInfo[@"NSHelpAnchor"] ?: @"(no help anchor)"];
}

/* One compile, asked synchronously: the answer is collected in an array rather than a __block variable
 * because a __block variable's storage moves to the heap when the block is copied and is freed with the
 * block, and reading it afterwards is then a read of freed memory. The store answers inside the call
 * when it is on the main thread and from the run loop when it is not, so both are turned. */
static NSString *rule_compile(WKContentRuleListStore *store, NSString *identifier, NSString *encoded)
{
    NSMutableArray *collected = [NSMutableArray array];
    [store compileContentRuleListForIdentifier:identifier encodedContentRuleList:encoded
                             completionHandler:^(WKContentRuleList *list, NSError *error) {
        [collected addObject:rule_answer(list, error)];
    }];
    ur_spin(^BOOL { return collected.count > 0; }, 2.0);
    return collected.count ? collected.firstObject : @"(the completion handler never ran)";
}

static NSString *rule_look_up(WKContentRuleListStore *store, NSString *identifier)
{
    NSMutableArray *collected = [NSMutableArray array];
    [store lookUpContentRuleListForIdentifier:identifier
                            completionHandler:^(WKContentRuleList *list, NSError *error) {
        [collected addObject:rule_answer(list, error)];
    }];
    ur_spin(^BOOL { return collected.count > 0; }, 2.0);
    return collected.count ? collected.firstObject : @"(the completion handler never ran)";
}

static NSString *rule_remove(WKContentRuleListStore *store, NSString *identifier)
{
    NSMutableArray *collected = [NSMutableArray array];
    [store removeContentRuleListForIdentifier:identifier
                            completionHandler:^(NSError *error) {
        [collected addObject:rule_answer(nil, error)];
    }];
    ur_spin(^BOOL { return collected.count > 0; }, 2.0);
    return collected.count ? collected.firstObject : @"(the completion handler never ran)";
}

static NSString *rule_identifiers(WKContentRuleListStore *store)
{
    NSMutableArray *collected = [NSMutableArray array];
    [store getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
        [collected addObject:[identifiers sortedArrayUsingSelector:@selector(compare:)]];
    }];
    ur_spin(^BOOL { return collected.count > 0; }, 2.0);
    if (!collected.count)
        return @"(the completion handler never ran)";
    NSArray *sorted = collected.firstObject;
    return [NSString stringWithFormat:@"%lu %@", (unsigned long)sorted.count,
                                      [sorted componentsJoinedByString:@","]];
}

/* The rules, written out rather than assembled from parts, because the point of asking the host is to
 * be told what it makes of a string this port wrote by hand. */
/* One rule as the JSON the store is handed, written out and serialised rather than assembled with
 * stringWithFormat, so the escaping is the serialiser's and no case can fail on a mis-quoted backslash.
 */
static NSString *rule_encoded(NSArray *rules)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:rules options:0 error:NULL];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static NSString *rule_compile_block(NSString *filter, NSString *type, NSDictionary *extra)
{
    NSMutableDictionary *action = [NSMutableDictionary dictionaryWithObject:type forKey:@"type"];
    if (extra)
        [action addEntriesFromDictionary:extra];
    return rule_encoded(@[@{@"trigger": @{@"url-filter": filter}, @"action": action}]);
}

static NSArray *content_rule_list_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];
    rule_store_reset();

    /* the two factory methods: the default store is one object for the process, and a store over a url
     * is an object of its own that sees what that url holds */
    [lines addObject:ur_line(@"case store.defaultStore.isOneObject",
                             ur_yes([WKContentRuleListStore defaultStore] == [WKContentRuleListStore defaultStore]))];
    WKContentRuleListStore *store = [WKContentRuleListStore storeWithURL:rule_store()];
    [lines addObject:ur_line(@"case store.overUrl.isAnObject", ur_yes(store != nil))];

    /* an empty store, asked all three ways */
    [lines addObject:ur_line(@"case empty.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case empty.lookUp", rule_look_up(store, @"absent"))];
    [lines addObject:ur_line(@"case empty.lookUpNil", rule_look_up(store, nil))];
    [lines addObject:ur_line(@"case empty.remove", rule_remove(store, @"absent"))];
    [lines addObject:ur_line(@"case empty.removeNil", rule_remove(store, nil))];

    /* the five things that are not the list at all */
    [lines addObject:ur_line(@"case refuse.notJSON", rule_compile(store, @"r1", @"not json at all"))];
    [lines addObject:ur_line(@"case refuse.notAnArray", rule_compile(store, @"r2", @"{\"trigger\":1}"))];
    [lines addObject:ur_line(@"case refuse.emptyArray", rule_compile(store, @"r3", @"[]"))];
    [lines addObject:ur_line(@"case refuse.notAnObject", rule_compile(store, @"r4", @"[\"x\"]"))];
    [lines addObject:ur_line(@"case refuse.nilEncoded", rule_compile(store, @"r5", nil))];
    /* the order of the checks inside one rule: a bad action is reported before a bad url-filter, and a
     * bad flag array before both */
    [lines addObject:ur_line(@"case refuse.noTrigger",
                             rule_compile(store, @"r6", @"[{\"action\":{\"type\":\"block\"}}]"))];
    [lines addObject:ur_line(@"case refuse.noAction",
                             rule_compile(store, @"r7",
                                          @"[{\"trigger\":{\"url-filter\":\"https://e.com/*\"}}]"))];
    [lines addObject:ur_line(@"case refuse.actionBeforeFilter",
                             rule_compile(store, @"r8", @"[{\"trigger\":{\"url-filter\":\"(\"},\"action\":{\"type\":\"nonsense\"}}]"))];
    [lines addObject:ur_line(@"case refuse.flagsBeforeAction",
                             rule_compile(store, @"r9",
                                          @"[{\"trigger\":{\"url-filter\":\"https://e.com/*\",\"resource-type\":[\"nonsense\"]},\"action\":{\"type\":\"nonsense\"}}]"))];
    [lines addObject:ur_line(@"case refuse.noUrlFilter",
                             rule_compile(store, @"r10", @"[{\"trigger\":{},\"action\":{\"type\":\"block\"}}]"))];
    [lines addObject:ur_line(@"case refuse.flagsNotAnArray",
                             rule_compile(store, @"r11",
                                          @"[{\"trigger\":{\"url-filter\":\"https://e.com/*\",\"resource-type\":\"document\"},\"action\":{\"type\":\"block\"}}]"))];
    [lines addObject:ur_line(@"case refuse.flagValue", rule_compile(store, @"r12",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"resource-type": @[@"webtransport"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.loadTypeCase", rule_compile(store, @"r13",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"load-type": @[@"FIRST-PARTY"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.emptyDomainList", rule_compile(store, @"r14",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.actionType", rule_compile(store, @"r15",
                             rule_compile_block(@"https://e.com/*", @"nonsense", nil)))];
    [lines addObject:ur_line(@"case refuse.actionTypeCase", rule_compile(store, @"r16",
                             rule_compile_block(@"https://e.com/*", @"BLOCK", nil)))];
    [lines addObject:ur_line(@"case refuse.cssWithoutSelector",
                             rule_compile(store, @"r17", rule_compile_block(@"https://e.com/*", @"css-display-none", nil)))];
    [lines addObject:ur_line(@"case refuse.disjunction",
                             rule_compile(store, @"r18", rule_compile_block(@"a|b", @"block", nil)))];
    [lines addObject:ur_line(@"case good.escapedDisjunction",
                             rule_compile(store, @"r19", rule_compile_block(@"a\\|b", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.countedRepetition",
                             rule_compile(store, @"r20", rule_compile_block(@"a{2,3}b", @"block", nil)))];
    [lines addObject:ur_line(@"case good.unpairedBrace",
                             rule_compile(store, @"r21", rule_compile_block(@"a{", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.lookahead",
                             rule_compile(store, @"r22", rule_compile_block(@"(?=a)b", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.lookbehind",
                             rule_compile(store, @"r23", rule_compile_block(@"(?<=a)b", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.flagsGroup",
                             rule_compile(store, @"r24", rule_compile_block(@"(?i)abc", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.pythonGroup",
                             rule_compile(store, @"r25", rule_compile_block(@"(?P<x>a)", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.namedBackreference",
                             rule_compile(store, @"r26", rule_compile_block(@"(?<x>a)\\k<x>", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.wordBoundary",
                             rule_compile(store, @"r27", rule_compile_block(@"\\bword\\b", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.unbalancedParenthesis",
                             rule_compile(store, @"r28", rule_compile_block(@"(", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.unbalancedBracket",
                             rule_compile(store, @"r29", rule_compile_block(@"[[", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.doubledQuantifier",
                             rule_compile(store, @"r30", rule_compile_block(@"a**", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.strayParenthesis",
                             rule_compile(store, @"r31", rule_compile_block(@"a)b", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.domainPattern",
                             rule_compile(store, @"r32",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"a|b"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.domainPatternAfterAction",
                             rule_compile(store, @"r36",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"a|b"]},
                                             @"action": @{@"type": @"nonsense"}}])))];
    [lines addObject:ur_line(@"case refuse.oneGoodRuleOneBad",
                             rule_compile(store, @"r37", rule_encoded(@[
                                 @{@"trigger": @{@"url-filter": @"https://e.com/*"}, @"action": @{@"type": @"block"}},
                                 @{@"trigger": @{@"url-filter": @"("}, @"action": @{@"type": @"block"}}])))];

    /* what the store holds after all of that: every refusal leaves it as it was */
    [lines addObject:ur_line(@"case afterRefusals.identifiers", rule_identifiers(store))];

    /* the five action types, and the patterns the port's own rule files are written with */
    [lines addObject:ur_line(@"case good.block", rule_compile(store, @"a1",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.blockCookies", rule_compile(store, @"a2",
                             rule_compile_block(@"https://e.com/*", @"block-cookies", nil)))];
    [lines addObject:ur_line(@"case good.ignorePreviousRules", rule_compile(store, @"a3",
                             rule_compile_block(@"https://e.com/*", @"ignore-previous-rules", nil)))];
    [lines addObject:ur_line(@"case good.makeHttps", rule_compile(store, @"a4",
                             rule_compile_block(@"https://e.com/*", @"make-https", nil)))];
    [lines addObject:ur_line(@"case good.makeHttpsWithPattern", rule_compile(store, @"a5",
                             rule_compile_block(@"https://e.com/*", @"make-https", @{@"pattern": @"nomatch"})))];
    [lines addObject:ur_line(@"case good.cssDisplayNone", rule_compile(store, @"a6",
                             rule_compile_block(@"https://e.com/*", @"css-display-none", @{@"selector": @".ad"})))];
    [lines addObject:ur_line(@"case good.star", rule_compile(store, @"a7",
                             rule_compile_block(@"https://*/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.leadingStarHost", rule_compile(store, @"a8",
                             rule_compile_block(@"*://*.example.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.charClass", rule_compile(store, @"a9",
                             rule_compile_block(@"https://e.com/[0-9]/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.posixClass", rule_compile(store, @"a10",
                             rule_compile_block(@"https://e.com/[[:alpha:]]/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.namedGroup", rule_compile(store, @"a11",
                             rule_compile_block(@"https://(e.com)/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.nonCapturingGroup", rule_compile(store, @"a12",
                             rule_compile_block(@"https://(?:e).com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.lazyQuantifier", rule_compile(store, @"a13",
                             rule_compile_block(@"https://e.com/+?x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.loneBracket", rule_compile(store, @"a14",
                             rule_compile_block(@"https://e.com/]/x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.numericBackreference", rule_compile(store, @"a15",
                             rule_compile_block(@"https://(e).com/\\1", @"block", nil)))];
    [lines addObject:ur_line(@"case good.twoRules", rule_compile(store, @"a16", rule_encoded(@[
        @{@"trigger": @{@"url-filter": @"https://a.com/*"}, @"action": @{@"type": @"block"}},
        @{@"trigger": @{@"url-filter": @"https://b.com/*"}, @"action": @{@"type": @"block-cookies"}}])))];
    [lines addObject:ur_line(@"case good.everyResourceType", rule_compile(store, @"a17",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"resource-type": @[@"document", @"image", @"style-sheet", @"script",
                                                                                 @"font", @"media", @"svg-document", @"raw", @"popup",
                                                                                 @"ping", @"csp-report", @"other", @"websocket"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case good.loadTypes", rule_compile(store, @"a18",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"load-type": @[@"first-party", @"third-party"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case good.domains", rule_compile(store, @"a19",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"*example.com", @"*.example.org"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.twoConditions", rule_compile(store, @"r33",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"*example.com"],
                                                             @"unless-domain": @[@"skip.example.com"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case good.lazyStar", rule_compile(store, @"r34",
                             rule_compile_block(@"https://e.com/*?x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.lazyOptional", rule_compile(store, @"r35",
                             rule_compile_block(@"https://e.com/x??", @"block", nil)))];
    [lines addObject:ur_line(@"case good.emptyGroup", rule_compile(store, @"r38",
                             rule_compile_block(@"https://e.com/()x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.emptyNonCapturingGroup", rule_compile(store, @"r39",
                             rule_compile_block(@"https://e.com/(?:)x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.quotedLiteral", rule_compile(store, @"r40",
                             rule_compile_block(@"https://e.com/\\Qa+b\\Ex", @"block", nil)))];
    [lines addObject:ur_line(@"case good.unicodeProperty", rule_compile(store, @"r41",
                             rule_compile_block(@"https://e.com/\\p{L}", @"block", nil)))];
    [lines addObject:ur_line(@"case good.emptyClass", rule_compile(store, @"r42",
                             rule_compile_block(@"https://e.com/[]x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.classEndingInBracket", rule_compile(store, @"r43",
                             rule_compile_block(@"https://e.com/[]]x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.negatedClassWithBracket", rule_compile(store, @"r44",
                             rule_compile_block(@"https://e.com/[^]a]", @"block", nil)))];
    [lines addObject:ur_line(@"case good.unknownPosixClass", rule_compile(store, @"r45",
                             rule_compile_block(@"https://e.com/[[:foo:]]x", @"block", nil)))];
    [lines addObject:ur_line(@"case good.loneCloseBrace", rule_compile(store, @"r46",
                             rule_compile_block(@"https://e.com/}", @"block", nil)))];
    [lines addObject:ur_line(@"case good.openBraceNoDigit", rule_compile(store, @"r47",
                             rule_compile_block(@"https://e.com/{,2}", @"block", nil)))];
    /* a leading quantifier: refused in a url-filter, accepted in a domain condition */
    [lines addObject:ur_line(@"case refuse.leadingStar", rule_compile(store, @"r48",
                             rule_compile_block(@"*example.com", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.leadingPlus", rule_compile(store, @"r49",
                             rule_compile_block(@"+example.com", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.leadingQuestion", rule_compile(store, @"r50",
                             rule_compile_block(@"?example.com", @"block", nil)))];
    [lines addObject:ur_line(@"case good.domainLeadingStar", rule_compile(store, @"r51",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"*example.com"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.domainLeadingPlus", rule_compile(store, @"r52",
                             rule_encoded(@[@{@"trigger": @{@"url-filter": @"https://e.com/*",
                                                             @"if-domain": @[@"+example.com"]},
                                             @"action": @{@"type": @"block"}}])))];
    [lines addObject:ur_line(@"case refuse.repeatedGroupName", rule_compile(store, @"r53",
                             rule_compile_block(@"https://(?<x>a)(?<x>b)", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.disjunctionInGroup", rule_compile(store, @"r54",
                             rule_compile_block(@"https://(?<n>a|b)", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.openClass", rule_compile(store, @"r55",
                             rule_compile_block(@"https://e.com/]a[", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.escapedBracketInClass", rule_compile(store, @"r56",
                             rule_compile_block(@"https://e.com/[a-\\]", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.classWithCountedRepetition", rule_compile(store, @"r57",
                             rule_compile_block(@"https://e.com/[a-z]{1,2}", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.strayCloseParenthesis", rule_compile(store, @"r58",
                             rule_compile_block(@"https://e.com/a)]", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.countedRepetitionOpenBrace", rule_compile(store, @"r59",
                             rule_compile_block(@"https://e.com/{2}", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.commentGroup", rule_compile(store, @"r60",
                             rule_compile_block(@"https://e.com/(?#c)", @"block", nil)))];
    [lines addObject:ur_line(@"case refuse.quotedNameGroup", rule_compile(store, @"r61",
                             rule_compile_block(@"https://e.com/(?'n'a)", @"block", nil)))];
    [lines addObject:ur_line(@"case good.secondBackreference", rule_compile(store, @"r62",
                             rule_compile_block(@"https://e.com/(a)(b)\\2", @"block", nil)))];
    [lines addObject:ur_line(@"case good.unknownKeys", rule_compile(store, @"a20",
                             rule_encoded(@[@{@"nope": @1,
                                              @"trigger": @{@"url-filter": @"https://e.com/*", @"nope": @1},
                                              @"action": @{@"type": @"block", @"nope": @1}}])))];
    /* an identifier of nothing and one of the empty string are both identifiers */
    [lines addObject:ur_line(@"case good.nilIdentifier", rule_compile(store, nil,
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.emptyIdentifier", rule_compile(store, @"",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    /* an identifier with a slash in it, which a store that names a file after the identifier cannot
     * keep and one that does not can */
    [lines addObject:ur_line(@"case good.slashIdentifier", rule_compile(store, @"a/b",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];

    [lines addObject:ur_line(@"case stored.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case stored.lookUp", rule_look_up(store, @"a1"))];
    [lines addObject:ur_line(@"case stored.lookUpSlash", rule_look_up(store, @"a/b"))];
    /* a refused compile leaves the store alone, which is what the identifier a list was stored under
     * answers after it has been asked to compile something unusable */
    [lines addObject:ur_line(@"case stored.compileOverIt", rule_compile(store, @"a1", @"[]"))];
    [lines addObject:ur_line(@"case stored.identifiersAfterRefusal", rule_identifiers(store))];
    [lines addObject:ur_line(@"case stored.rewrite", rule_compile(store, @"a1",
                             rule_compile_block(@"https://other.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case stored.identifiersAfterRewrite", rule_identifiers(store))];

    /* a SECOND store object over the same url, which is how the store is asked whether what it holds
     * is in the url or in the object */
    WKContentRuleListStore *again = [WKContentRuleListStore storeWithURL:rule_store()];
    [lines addObject:ur_line(@"case second.identifiers", rule_identifiers(again))];
    [lines addObject:ur_line(@"case second.lookUp", rule_look_up(again, @"a2"))];

    /* and taking them out, one at a time and all at once */
    [lines addObject:ur_line(@"case remove.one", rule_remove(store, @"a1"))];
    [lines addObject:ur_line(@"case remove.oneAgain", rule_remove(store, @"a1"))];
    [lines addObject:ur_line(@"case remove.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case remove.lookUpAfter", rule_look_up(store, @"a1"))];

    /* and a store whose url a regular file occupies: the one refusal a program can arrange, and the
     * sentence for it is the release's own and not one of the list's */
    WKContentRuleListStore *blocked = [WKContentRuleListStore storeWithURL:blocked_rule_store()];
    [lines addObject:ur_line(@"case blocked.identifiers", rule_identifiers(blocked))];
    [lines addObject:ur_line(@"case blocked.compile", rule_compile(blocked, @"b1",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case blocked.lookUp", rule_look_up(blocked, @"b1"))];
    return lines;
}