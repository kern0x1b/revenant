#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL accepted(NSString *name)
{
    @try {
        return [[CSCustomAttributeKey alloc] initWithKeyName:name] != nil;
    } @catch (NSException *e) {
        return NO;
    }
}

static NSString *withCharacter(unichar c)
{
    unichar units[3] = {'a', c, 'b'};
    return [NSString stringWithCharacters:units length:3];
}

static CSCustomAttributeKey *key(NSString *name, BOOL searchable, BOOL searchableByDefault, BOOL unique, BOOL multiValued)
{
    return [[CSCustomAttributeKey alloc] initWithKeyName:name searchable:searchable searchableByDefault:searchableByDefault
                                                  unique:unique multiValued:multiValued];
}

static void names(void)
{
    for (unichar c = 1; c < 128; c++)
        printf("name a+char %d+b accepted: %d\n", c, accepted(withCharacter(c)));
    printf("name with NUL accepted: %d\n", accepted(withCharacter(0)));
    printf("name with a space accepted: %d\n", accepted(@"a b"));
    printf("name with a trailing space accepted: %d\n", accepted(@"a "));
    printf("name with a leading dollar accepted: %d\n", accepted(@"$a"));
    printf("empty name accepted: %d\n", accepted(@""));
    NSString *none = nil;
    printf("nil name gives no key: %d\n", [[CSCustomAttributeKey alloc] initWithKeyName:none] == nil);
    printf("nil name with flags gives no key: %d\n", key(nil, NO, NO, NO, NO) == nil);
    printf("refused name with flags gives no key: %d\n", key(@"a-b", YES, YES, YES, YES) == nil);
    printf("two refused characters, a-.b accepted: %d\n", accepted(@"a-.b"));
    NSArray *others = @[@"é", @" ", @" ", @"€", @"中", @"\U0001F600", @"x́"];
    for (NSString *s in others)
        printf("non-ASCII name accepted (first unit %04x): %d\n", [s characterAtIndex:0], accepted(s));
    NSMutableString *long1000 = [NSMutableString string];
    for (int i = 0; i < 1000; i++)
        [long1000 appendString:@"c"];
    printf("name of 1000 characters accepted: %d\n", accepted(long1000));
    for (int i = 0; i < 9010; i++)
        [long1000 appendString:@"d"];
    printf("name of 10010 characters accepted: %d\n", accepted(long1000));
}

static void flags(void)
{
    CSCustomAttributeKey *d = [[CSCustomAttributeKey alloc] initWithKeyName:@"dflt"];
    printf("default flags: searchable=%d searchableByDefault=%d unique=%d multiValued=%d\n", d.searchable, d.searchableByDefault,
           d.unique, d.multiValued);
    CSCustomAttributeKey *f = key(@"fl", YES, NO, YES, YES);
    printf("four flags: searchable=%d searchableByDefault=%d unique=%d multiValued=%d\n", f.searchable, f.searchableByDefault,
           f.unique, f.multiValued);
    CSCustomAttributeKey *g = key(@"zz", NO, YES, NO, NO);
    printf("searchableByDefault only: searchable=%d searchableByDefault=%d unique=%d multiValued=%d\n", g.searchable,
           g.searchableByDefault, g.unique, g.multiValued);
    printf("name getter: %s\n", f.keyName.UTF8String);
    NSMutableString *source = [NSMutableString stringWithString:@"ab"];
    CSCustomAttributeKey *kept = [[CSCustomAttributeKey alloc] initWithKeyName:source];
    [source appendString:@"c"];
    printf("name after the source is mutated: %s\n", kept.keyName.UTF8String);
}

static void equality(void)
{
    CSCustomAttributeKey *base = key(@"fl", YES, NO, YES, YES);
    printf("equal to same name, other flags: %d, hash same: %d\n", [base isEqual:key(@"fl", NO, YES, NO, NO)],
           [base hash] == [key(@"fl", NO, YES, NO, NO) hash]);
    printf("equal to other name: %d\n", [base isEqual:key(@"other", YES, NO, YES, YES)]);
    printf("equal to a string of its name: %d\n", [base isEqual:@"fl"]);
    printf("equal to a mutable string of its name: %d\n", [base isEqual:[NSMutableString stringWithString:@"fl"]]);
    printf("equal to a string of another case: %d\n", [base isEqual:@"FL"]);
    printf("equal to a number: %d\n", [base isEqual:@5]);
    printf("equal to nil: %d\n", [base isEqual:nil]);
    printf("equal to itself: %d\n", [base isEqual:base]);
    printf("hash equals the name's hash: %d\n", [base hash] == [@"fl" hash]);
}

static void copying(void)
{
    CSCustomAttributeKey *f = key(@"fl", YES, NO, YES, YES);
    CSCustomAttributeKey *c = [f copy];
    printf("copy class: %s, same object: %d, equal: %d\n", object_getClassName(c), c == f, [c isEqual:f]);
    printf("copy flags: searchable=%d searchableByDefault=%d unique=%d multiValued=%d\n", c.searchable, c.searchableByDefault,
           c.unique, c.multiValued);
}

static void text(void)
{
    CSCustomAttributeKey *f = key(@"fl", YES, NO, YES, YES);
    printf("description: %s\n", [[f description] UTF8String]);
    printf("debugDescription: %s\n", [[f debugDescription] UTF8String]);
}

static void coding(void)
{
    CSCustomAttributeKey *f = key(@"fl", YES, NO, YES, YES);
    CSCustomAttributeKey *back = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:f]];
    printf("coding class: %s\n", object_getClassName(back));
    printf("coding name: %s\n", back.keyName.UTF8String);
    printf("coding flags: searchable=%d searchableByDefault=%d unique=%d multiValued=%d\n", back.searchable, back.searchableByDefault,
           back.unique, back.multiValued);
    printf("supportsSecureCoding: %d\n", [CSCustomAttributeKey supportsSecureCoding]);
}

static void plainInit(void)
{
    @try {
        id raw = ((id (*)(id, SEL))objc_msgSend)([CSCustomAttributeKey alloc], sel_registerName("init"));
        printf("plain init returned: %s\n", raw ? "an object" : "nil");
    } @catch (NSException *e) {
        printf("plain init raised: %s, reason: %s\n", e.name.UTF8String, e.reason.UTF8String);
    }
}

int main(void)
{
    @autoreleasepool {
        names();
        flags();
        equality();
        copying();
        text();
        coding();
        plainInit();
    }
    return 0;
}
