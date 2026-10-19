#import <CoreData/CoreData.h>
#import <objc/message.h>

static int checks, failures;

static NSString *plain(id value)
{
    NSString *text = [value description] ?: @"(nil)";
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    return [[NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL]
               stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
}

static void same(id ours, id theirs, NSString *what)
{
    checks++;
    if ([plain(ours) isEqualToString:plain(theirs)])
        return;
    printf("FAIL %s: ours %s, Core Data %s\n", what.UTF8String, plain(ours).UTF8String, plain(theirs).UTF8String);
    failures++;
}

static NSDictionary *answers(NSPersistentStoreDescription *d)
{
    return @{@"URL": d.URL ?: @"(nil)", @"type": d.type ?: @"(nil)", @"configuration": d.configuration ?: @"(nil)",
             @"options": d.options, @"readOnly": @(d.readOnly), @"timeout": @(d.timeout), @"pragmas": d.sqlitePragmas,
             @"asynchronous": @(d.shouldAddStoreAsynchronously), @"migrate": @(d.shouldMigrateStoreAutomatically),
             @"infer": @(d.shouldInferMappingModelAutomatically)};
}

static void compare(NSString *what, void (^change)(NSPersistentStoreDescription *))
{
    Class mine = NSClassFromString(@"CharonHostNSPersistentStoreDescription");
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/charon-store.sqlite"];
    for (NSNumber *withURL in @[@NO, @YES]) {
        NSPersistentStoreDescription *ours = withURL.boolValue ? [[mine alloc] initWithURL:url] : [[mine alloc] init];
        NSPersistentStoreDescription *theirs = withURL.boolValue ? [[NSPersistentStoreDescription alloc] initWithURL:url]
                                                                 : [[NSPersistentStoreDescription alloc] init];
        change(ours);
        change(theirs);
        NSString *named = [NSString stringWithFormat:@"%@%@", what, withURL.boolValue ? @", with a URL" : @""];
        NSDictionary *a = answers(ours), *b = answers(theirs);
        for (NSString *key in b)
            same(a[key], b[key], [NSString stringWithFormat:@"%@: %@", named, key]);
        same(ours, theirs, [named stringByAppendingString:@": description"]);
        NSPersistentStoreDescription *oursCopy = [ours copy], *theirsCopy = [theirs copy];
        same(@([oursCopy isEqual:ours] && oursCopy != ours && oursCopy.hash == ours.hash),
             @([theirsCopy isEqual:theirs] && theirsCopy != theirs && theirsCopy.hash == theirs.hash), [named stringByAppendingString:@": copy"]);
        change(oursCopy);
        change(theirsCopy);
        oursCopy.type = NSInMemoryStoreType;
        theirsCopy.type = NSInMemoryStoreType;
        same(@([oursCopy isEqual:ours]), @([theirsCopy isEqual:theirs]), [named stringByAppendingString:@": a copy of another type"]);
    }
}

int main(void)
{
    @autoreleasepool {
        compare(@"fresh", ^(NSPersistentStoreDescription *d) {});
        compare(@"read only, a timeout, asynchronous", ^(NSPersistentStoreDescription *d) {
            d.readOnly = YES; d.timeout = 3; d.shouldAddStoreAsynchronously = YES;
        });
        compare(@"no migration or inference", ^(NSPersistentStoreDescription *d) {
            d.shouldMigrateStoreAutomatically = NO; d.shouldInferMappingModelAutomatically = NO;
        });
        compare(@"a pragma set and taken away", ^(NSPersistentStoreDescription *d) {
            [d setValue:@"WAL" forPragmaNamed:@"journal_mode"]; [d setValue:@"FULL" forPragmaNamed:@"synchronous"];
            [d setValue:nil forPragmaNamed:@"journal_mode"];
        });
        compare(@"an option set and taken away", ^(NSPersistentStoreDescription *d) {
            [d setOption:@1 forKey:@"custom"]; [d setOption:@2 forKey:@"kept"]; [d setOption:nil forKey:@"custom"];
        });
        compare(@"a configuration, a type and no URL", ^(NSPersistentStoreDescription *d) {
            d.configuration = @"Default"; d.type = NSBinaryStoreType; d.URL = nil;
        });
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures;
}
