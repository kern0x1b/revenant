// differential.m - the same program, built once against the host's CoreSpotlight and once against the port's CSPerson.m and
// CSSearchQueryContext.m. Every line it prints must be the same on both sides, after run.sh has replaced object addresses.
// Each line is one answer the host was measured to give: defaults, coercion of nil, copy and storage semantics, equality,
// hashing, the text of description, and what a coded and decoded copy reads back.
#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <objc/runtime.h>

static void line(NSString *name, id value)
{
    printf("%s: %s\n", name.UTF8String, value ? [[value description] UTF8String] : "(nil)");
}

static void raised(NSString *name, void (^block)(void))
{
    @try {
        block();
        printf("%s: no exception\n", name.UTF8String);
    } @catch (NSException *e) {
        printf("%s: raised %s\n", name.UTF8String, e.name.UTF8String);
    }
}

static CSPerson *person(NSString *name, NSArray *handles, NSString *identifier, NSString *contact)
{
    CSPerson *p = [[CSPerson alloc] initWithDisplayName:name handles:handles handleIdentifier:identifier];
    p.contactIdentifier = contact;
    return p;
}

static void queryContext(void)
{
    CSSearchQueryContext *c = [[CSSearchQueryContext alloc] init];
    line(@"ctx.fetchAttributes", c.fetchAttributes);
    line(@"ctx.filterQueries", c.filterQueries);
    line(@"ctx.keyboardLanguage", c.keyboardLanguage);
    printf("ctx.sourceOptions: %lu\n", (unsigned long)c.sourceOptions);
    CSSearchQueryContext *copy = [c copy];
    printf("ctx.copy class: %s, same object: %d\n", object_getClassName(copy), copy == c);
    printf("ctx.copy isEqual: %d\n", [c isEqual:copy]);
    printf("ctx.isEqual two defaults: %d\n", [c isEqual:[[CSSearchQueryContext alloc] init]]);
    printf("ctx.hash equal for two defaults: %d\n", [c hash] == [[[CSSearchQueryContext alloc] init] hash]);
    c.fetchAttributes = @[@"title"];
    c.filterQueries = @[@"a"];
    c.keyboardLanguage = @"en";
    c.sourceOptions = 1;
    line(@"ctx.set fetchAttributes", c.fetchAttributes);
    line(@"ctx.set keyboardLanguage", c.keyboardLanguage);
    printf("ctx.set sourceOptions: %lu\n", (unsigned long)c.sourceOptions);
    CSSearchQueryContext *kept = [c copy];
    line(@"ctx.copy keeps keyboardLanguage", kept.keyboardLanguage);
    line(@"ctx.copy keeps fetchAttributes", kept.fetchAttributes);
    line(@"ctx.copy keeps filterQueries", kept.filterQueries);
    printf("ctx.copy keeps sourceOptions: %lu\n", (unsigned long)kept.sourceOptions);
    NSArray *none = nil;
    raised(@"ctx.nil fetchAttributes", ^{ c.fetchAttributes = none; });
    line(@"ctx.after nil fetchAttributes", c.fetchAttributes);
    raised(@"ctx.nil filterQueries", ^{ c.filterQueries = none; });
    line(@"ctx.after nil filterQueries", c.filterQueries);
    NSMutableArray *source = [NSMutableArray arrayWithObject:@"x"];
    c.filterQueries = source;
    [source addObject:@"y"];
    line(@"ctx.filterQueries after mutating source", c.filterQueries);
    CSSearchQueryContext *back = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:c]];
    printf("ctx.coding class: %s\n", object_getClassName(back));
    line(@"ctx.coding keyboardLanguage", back.keyboardLanguage);
    printf("ctx.coding sourceOptions: %lu\n", (unsigned long)back.sourceOptions);
    line(@"ctx.coding filterQueries", back.filterQueries);
    line(@"ctx.coding fetchAttributes", back.fetchAttributes);
    printf("ctx.supportsSecureCoding: %d\n", [CSSearchQueryContext supportsSecureCoding]);
}

static void personValues(void)
{
    CSPerson *p = person(@"Ann", @[@"a@b.c"], @"h1", nil);
    line(@"person.displayName", p.displayName);
    line(@"person.handles", p.handles);
    line(@"person.handleIdentifier", p.handleIdentifier);
    line(@"person.contactIdentifier", p.contactIdentifier);
    p.contactIdentifier = @"cid";
    line(@"person.contactIdentifier set", p.contactIdentifier);
    CSPerson *copy = [p copy];
    printf("person.copy class: %s, same object: %d\n", object_getClassName(copy), copy == p);
    line(@"person.copy contactIdentifier", copy.contactIdentifier);
    line(@"person.nil displayName", person(nil, @[], @"", nil).displayName);
    line(@"person.empty handles", person(@"A", @[], @"", nil).handles);
    line(@"person.empty handleIdentifier", person(@"A", @[], @"", nil).handleIdentifier);
    raised(@"person.nil handles", ^{ line(@"person.nil handles stored", person(@"A", nil, @"h", nil).handles); });
    raised(@"person.nil handleIdentifier", ^{ line(@"person.nil handleIdentifier stored", person(@"A", @[], nil, nil).handleIdentifier); });
    NSMutableArray *handles = [NSMutableArray arrayWithObject:@"one"];
    CSPerson *held = person(@"A", handles, @"h", nil);
    [handles addObject:@"two"];
    line(@"person.handles after mutating source", held.handles);
    NSMutableString *name = [NSMutableString stringWithString:@"Ann"];
    CSPerson *named = person(name, @[], @"h", nil);
    [name appendString:@"X"];
    line(@"person.displayName after mutating source", named.displayName);
    NSMutableString *contact = [NSMutableString stringWithString:@"c"];
    CSPerson *copied = person(@"A", @[], @"h", nil);
    copied.contactIdentifier = contact;
    [contact appendString:@"X"];
    line(@"person.contactIdentifier after mutating source", copied.contactIdentifier);
}

static void personEquality(void)
{
    CSPerson *base = person(@"Ann", @[@"a"], @"h", @"c");
    CSPerson *same = person(@"Ann", @[@"a"], @"h", @"c");
    printf("person.isEqual same content: %d, hash same: %d\n", [base isEqual:same], [base hash] == [same hash]);
    printf("person.isEqual other displayName: %d\n", [base isEqual:person(@"Bob", @[@"a"], @"h", @"c")]);
    printf("person.isEqual other handles: %d\n", [base isEqual:person(@"Ann", @[@"b"], @"h", @"c")]);
    printf("person.isEqual other handleIdentifier: %d\n", [base isEqual:person(@"Ann", @[@"a"], @"x", @"c")]);
    printf("person.isEqual other contactIdentifier: %d\n", [base isEqual:person(@"Ann", @[@"a"], @"h", @"z")]);
    printf("person.isEqual nil vs empty contactIdentifier: %d\n", [person(@"A", @[], @"h", nil) isEqual:person(@"A", @[], @"h", @"")]);
    printf("person.isEqual handles order: %d\n", [person(@"A", @[@"1", @"2"], @"h", nil) isEqual:person(@"A", @[@"2", @"1"], @"h", nil)]);
    printf("person.isEqual nil vs empty displayName: %d\n", [person(nil, @[], @"h", nil) isEqual:person(@"", @[], @"h", nil)]);
    printf("person.isEqual nil: %d, string: %d\n", [base isEqual:nil], [base isEqual:@"Ann"]);
    printf("person.copy isEqual: %d\n", [[base copy] isEqual:base]);
    printf("person.contactIdentifier nil vs unset: %d\n", [person(@"Ann", @[@"a"], @"h", nil) isEqual:person(@"Ann", @[@"a"], @"h", nil)]);
}

static void personText(void)
{
    line(@"person.description two handles", person(@"Ann", @[@"x", @"y"], @"h", nil));
    line(@"person.description nil name, no handles", person(nil, @[], @"h", nil));
    line(@"person.description empty name, one handle", person(@"", @[@"x"], @"h", nil));
    line(@"person.description nil handles", person(@"A", nil, @"h", nil));
    line(@"person.debugDescription", [person(@"Ann", @[@"x", @"y"], @"h", nil) debugDescription]);
}

static void personCoding(void)
{
    CSPerson *back = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:person(@"Ann", @[@"a@b.c"], @"h1", @"cid")]];
    printf("person.coding class: %s\n", object_getClassName(back));
    line(@"person.coding displayName", back.displayName);
    line(@"person.coding handles", back.handles);
    line(@"person.coding handleIdentifier", back.handleIdentifier);
    line(@"person.coding contactIdentifier", back.contactIdentifier);
    CSPerson *nameless = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:person(nil, @[], @"h", nil)]];
    line(@"person.coding nil displayName", nameless.displayName);
    printf("person.supportsSecureCoding: %d\n", [CSPerson supportsSecureCoding]);
}

int main(void)
{
    @autoreleasepool {
        queryContext();
        personValues();
        personEquality();
        personText();
        personCoding();
    }
    return 0;
}
