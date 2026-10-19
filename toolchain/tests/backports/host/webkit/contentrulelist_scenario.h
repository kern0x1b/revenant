#import "../uikit2/uirest.h"
#import <WebKit/WebKit.h>

static NSURL *rule_store(void)
{
    const char *given = getenv("REVENANT_RULE_STORE");
    NSString *path = given ? @(given) : [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-rule-store"];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

static NSURL *blocked_rule_store(void)
{
    return [rule_store().URLByDeletingLastPathComponent URLByAppendingPathComponent:@"blocked.store"];
}

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

static NSString *rule_answer(WKContentRuleList *list, NSError *error)
{
    NSString *found = list ? [NSString stringWithFormat:@"list %@", list.identifier] : @"nil";
    if (!error)
        return [NSString stringWithFormat:@"%@ | no error", found];
    return [NSString stringWithFormat:@"%@ | %@ %ld | %@", found, error.domain, (long)error.code,
                                      error.userInfo[@"NSHelpAnchor"] ?: @"(no help anchor)"];
}

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

    [lines addObject:ur_line(@"case store.defaultStore.isOneObject",
                             ur_yes([WKContentRuleListStore defaultStore] == [WKContentRuleListStore defaultStore]))];
    WKContentRuleListStore *store = [WKContentRuleListStore storeWithURL:rule_store()];
    [lines addObject:ur_line(@"case store.overUrl.isAnObject", ur_yes(store != nil))];

    [lines addObject:ur_line(@"case empty.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case empty.lookUp", rule_look_up(store, @"absent"))];
    [lines addObject:ur_line(@"case empty.lookUpNil", rule_look_up(store, nil))];
    [lines addObject:ur_line(@"case empty.remove", rule_remove(store, @"absent"))];
    [lines addObject:ur_line(@"case empty.removeNil", rule_remove(store, nil))];

    [lines addObject:ur_line(@"case refuse.notJSON", rule_compile(store, @"r1", @"not json at all"))];
    [lines addObject:ur_line(@"case refuse.notAnArray", rule_compile(store, @"r2", @"{\"trigger\":1}"))];
    [lines addObject:ur_line(@"case refuse.emptyArray", rule_compile(store, @"r3", @"[]"))];
    [lines addObject:ur_line(@"case refuse.notAnObject", rule_compile(store, @"r4", @"[\"x\"]"))];
    [lines addObject:ur_line(@"case refuse.nilEncoded", rule_compile(store, @"r5", nil))];
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

    [lines addObject:ur_line(@"case afterRefusals.identifiers", rule_identifiers(store))];

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
    [lines addObject:ur_line(@"case good.nilIdentifier", rule_compile(store, nil,
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.emptyIdentifier", rule_compile(store, @"",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case good.slashIdentifier", rule_compile(store, @"a/b",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];

    [lines addObject:ur_line(@"case stored.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case stored.lookUp", rule_look_up(store, @"a1"))];
    [lines addObject:ur_line(@"case stored.lookUpSlash", rule_look_up(store, @"a/b"))];
    [lines addObject:ur_line(@"case stored.compileOverIt", rule_compile(store, @"a1", @"[]"))];
    [lines addObject:ur_line(@"case stored.identifiersAfterRefusal", rule_identifiers(store))];
    [lines addObject:ur_line(@"case stored.rewrite", rule_compile(store, @"a1",
                             rule_compile_block(@"https://other.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case stored.identifiersAfterRewrite", rule_identifiers(store))];

    WKContentRuleListStore *again = [WKContentRuleListStore storeWithURL:rule_store()];
    [lines addObject:ur_line(@"case second.identifiers", rule_identifiers(again))];
    [lines addObject:ur_line(@"case second.lookUp", rule_look_up(again, @"a2"))];

    [lines addObject:ur_line(@"case remove.one", rule_remove(store, @"a1"))];
    [lines addObject:ur_line(@"case remove.oneAgain", rule_remove(store, @"a1"))];
    [lines addObject:ur_line(@"case remove.identifiers", rule_identifiers(store))];
    [lines addObject:ur_line(@"case remove.lookUpAfter", rule_look_up(store, @"a1"))];

    WKContentRuleListStore *blocked = [WKContentRuleListStore storeWithURL:blocked_rule_store()];
    [lines addObject:ur_line(@"case blocked.identifiers", rule_identifiers(blocked))];
    [lines addObject:ur_line(@"case blocked.compile", rule_compile(blocked, @"b1",
                             rule_compile_block(@"https://e.com/*", @"block", nil)))];
    [lines addObject:ur_line(@"case blocked.lookUp", rule_look_up(blocked, @"b1"))];
    return lines;
}
