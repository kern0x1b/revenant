#import <Foundation/Foundation.h>

typedef void (^SuiteRecorder)(NSString *name, NSString *value);

static NSString *suite_describe(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[NSData class]])
        return [NSString stringWithFormat:@"data(%lu)", (unsigned long)[value length]];
    NSString *cls = [value isKindOfClass:[NSNumber class]] ? @"number" : ([value isKindOfClass:[NSString class]] ? @"string" : ([value isKindOfClass:[NSArray class]] ? @"array" : ([value isKindOfClass:[NSDictionary class]] ? @"dict" : NSStringFromClass([value class]))));
    return [NSString stringWithFormat:@"%@:%@", cls, value];
}

static void suite_run(NSUserDefaults *(^make)(void), SuiteRecorder record)
{
    NSUserDefaults *d = make();
    record(@"unset object", suite_describe([d objectForKey:@"missing"]));
    record(@"unset integer", [NSString stringWithFormat:@"%ld", (long)[d integerForKey:@"missing"]]);
    record(@"unset bool", [NSString stringWithFormat:@"%d", [d boolForKey:@"missing"]]);
    record(@"unset double", [NSString stringWithFormat:@"%g", [d doubleForKey:@"missing"]]);
    record(@"unset string", suite_describe([d stringForKey:@"missing"]));
    record(@"unset url", suite_describe([d URLForKey:@"missing"]));

    [d setObject:@"abc" forKey:@"s"];
    record(@"string object", suite_describe([d objectForKey:@"s"]));
    record(@"string integer", [NSString stringWithFormat:@"%ld", (long)[d integerForKey:@"s"]]);
    record(@"string bool", [NSString stringWithFormat:@"%d", [d boolForKey:@"s"]]);
    record(@"string array", suite_describe([d arrayForKey:@"s"]));
    [d setObject:@"42" forKey:@"n"];
    record(@"numeric string integer", [NSString stringWithFormat:@"%ld", (long)[d integerForKey:@"n"]]);
    record(@"numeric string double", [NSString stringWithFormat:@"%g", [d doubleForKey:@"n"]]);
    record(@"numeric string bool", [NSString stringWithFormat:@"%d", [d boolForKey:@"n"]]);
    [d setObject:@"YES" forKey:@"y"];
    record(@"YES string bool", [NSString stringWithFormat:@"%d", [d boolForKey:@"y"]]);
    [d setDouble:3.75 forKey:@"d"];
    record(@"double string", suite_describe([d stringForKey:@"d"]));
    record(@"double integer", [NSString stringWithFormat:@"%ld", (long)[d integerForKey:@"d"]]);
    record(@"double float", [NSString stringWithFormat:@"%g", [d floatForKey:@"d"]]);
    record(@"double bool", [NSString stringWithFormat:@"%d", [d boolForKey:@"d"]]);
    [d setInteger:-7 forKey:@"i"];
    record(@"integer object", suite_describe([d objectForKey:@"i"]));
    record(@"integer string", suite_describe([d stringForKey:@"i"]));
    [d setBool:YES forKey:@"b"];
    record(@"bool object", suite_describe([d objectForKey:@"b"]));
    record(@"bool string", suite_describe([d stringForKey:@"b"]));
    [d setFloat:0.5f forKey:@"f"];
    record(@"float double", [NSString stringWithFormat:@"%g", [d doubleForKey:@"f"]]);

    [d setObject:@[@"a", @"b"] forKey:@"arr"];
    [d setObject:@[@"a", @1] forKey:@"mixed"];
    [d setObject:@{@"k": @"v"} forKey:@"dict"];
    [d setObject:[NSData dataWithBytes:"xyz" length:3] forKey:@"data"];
    record(@"array", suite_describe([d arrayForKey:@"arr"]));
    record(@"string array", suite_describe([d stringArrayForKey:@"arr"]));
    record(@"mixed string array", suite_describe([d stringArrayForKey:@"mixed"]));
    record(@"mixed array", suite_describe([d arrayForKey:@"mixed"]));
    record(@"dict", suite_describe([d dictionaryForKey:@"dict"]));
    record(@"dict as array", suite_describe([d arrayForKey:@"dict"]));
    record(@"data", suite_describe([d dataForKey:@"data"]));
    record(@"data as string", suite_describe([d stringForKey:@"data"]));

    [d setURL:[NSURL fileURLWithPath:@"/tmp/charon-suite"] forKey:@"fileurl"];
    record(@"file url object", suite_describe([d objectForKey:@"fileurl"]));
    record(@"file url", suite_describe([[d URLForKey:@"fileurl"] path]));
    [d setURL:[NSURL URLWithString:@"https://example.invalid/a?b=c"] forKey:@"weburl"];
    record(@"web url object", [[d objectForKey:@"weburl"] isKindOfClass:[NSData class]] ? @"data" : @"other");
    record(@"web url", suite_describe([[d URLForKey:@"weburl"] absoluteString]));
    [d setObject:@"relative/path" forKey:@"pathstring"];
    NSURL *relative = [d URLForKey:@"pathstring"];
    record(@"string as url", [NSString stringWithFormat:@"%d %@", relative.isFileURL, relative.lastPathComponent]);

    [d registerDefaults:@{@"reg": @"fallback", @"s": @"ignored", @"regnum": @9}];
    record(@"registered", suite_describe([d objectForKey:@"reg"]));
    record(@"registered integer", [NSString stringWithFormat:@"%ld", (long)[d integerForKey:@"regnum"]]);
    record(@"set wins over registered", suite_describe([d objectForKey:@"s"]));
    [d setObject:@"own" forKey:@"reg"];
    record(@"overridden", suite_describe([d objectForKey:@"reg"]));
    [d removeObjectForKey:@"reg"];
    record(@"removed back to registered", suite_describe([d objectForKey:@"reg"]));
    [d removeObjectForKey:@"s"];
    record(@"removed", suite_describe([d objectForKey:@"s"]));
    [d setObject:nil forKey:@"n"];
    record(@"set nil removes", suite_describe([d objectForKey:@"n"]));

    NSDictionary *all = [d dictionaryRepresentation];
    record(@"representation has set", suite_describe(all[@"arr"]));
    record(@"representation has registered", suite_describe(all[@"regnum"]));
    record(@"representation lacks removed", suite_describe(all[@"n"]));

    __block BOOL notified = NO;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) { notified = YES; }];
    [d setObject:@"note" forKey:@"note"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    record(@"change notification", [NSString stringWithFormat:@"%d", notified]);

    [d synchronize];
    NSUserDefaults *other = make();
    record(@"second instance sees data", suite_describe([other objectForKey:@"arr"]));
    record(@"second instance sees integer", [NSString stringWithFormat:@"%ld", (long)[other integerForKey:@"i"]]);
    record(@"second instance lacks registered", suite_describe([other objectForKey:@"regnum"]));
}
