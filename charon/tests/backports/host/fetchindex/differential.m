#import <CoreData/CoreData.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

@interface NSEntityDescription (CharonHost)
- (NSArray *)charonHostindexes;
- (void)charonHostsetIndexes:(NSArray *)indexes;
- (NSExpression *)charonHostcoreSpotlightDisplayNameExpression;
- (void)charonHostsetCoreSpotlightDisplayNameExpression:(NSExpression *)expression;
@end

@interface NSObject (FetchIndexAccess)
- (NSPropertyDescription *)property;
- (NSString *)propertyName;
- (NSInteger)collationType;
- (void)setCollationType:(NSInteger)type;
- (BOOL)isAscending;
- (void)setAscending:(BOOL)ascending;
- (id)indexDescription;
- (NSArray *)elements;
- (void)setElements:(NSArray *)elements;
- (id)entity;
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSPredicate *)partialIndexPredicate;
- (void)setPartialIndexPredicate:(NSPredicate *)predicate;
@end

typedef struct {
    BOOL ours;
} Kit;

static Class element_class(Kit kit) { return NSClassFromString(kit.ours ? @"CharonHostNSFetchIndexElementDescription" : @"NSFetchIndexElementDescription"); }
static Class index_class(Kit kit) { return NSClassFromString(kit.ours ? @"CharonHostNSFetchIndexDescription" : @"NSFetchIndexDescription"); }

static id make_element(Kit kit, NSPropertyDescription *property, NSInteger collation)
{
    return ((id (*)(id, SEL, id, NSInteger))objc_msgSend)([element_class(kit) alloc], @selector(initWithProperty:collationType:), property, collation);
}

static id make_index(Kit kit, NSString *name, NSArray *elements)
{
    return ((id (*)(id, SEL, id, id))objc_msgSend)([index_class(kit) alloc], @selector(initWithName:elements:), name, elements);
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]];
    }
    return @"ok";
}

static NSString *plain(NSString *text)
{
    return [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

static NSAttributeDescription *attribute(NSString *name, NSAttributeType type)
{
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = type;
    a.optional = YES;
    return a;
}

typedef struct {
    NSAttributeDescription *name, *lat, *flt, *i16, *i32, *i64, *dec, *flag, *date, *data;
    NSRelationshipDescription *rel;
    NSFetchedPropertyDescription *fetched;
    NSEntityDescription *entity;
} World;

static World make_world(void)
{
    World w;
    w.name = attribute(@"name", NSStringAttributeType);
    w.lat = attribute(@"lat", NSDoubleAttributeType);
    w.flt = attribute(@"flt", NSFloatAttributeType);
    w.i16 = attribute(@"i16", NSInteger16AttributeType);
    w.i32 = attribute(@"i32", NSInteger32AttributeType);
    w.i64 = attribute(@"i64", NSInteger64AttributeType);
    w.dec = attribute(@"dec", NSDecimalAttributeType);
    w.flag = attribute(@"b", NSBooleanAttributeType);
    w.date = attribute(@"dt", NSDateAttributeType);
    w.data = attribute(@"bin", NSBinaryDataAttributeType);
    w.rel = [[NSRelationshipDescription alloc] init];
    w.rel.name = @"rel";
    w.rel.maxCount = 1;
    w.rel.optional = YES;
    w.fetched = [[NSFetchedPropertyDescription alloc] init];
    w.fetched.name = @"fetched";
    w.entity = [[NSEntityDescription alloc] init];
    w.entity.name = @"E";
    w.entity.properties = @[w.name, w.lat, w.flt, w.i16, w.i32, w.i64, w.dec, w.flag, w.date, w.data, w.rel];
    w.rel.destinationEntity = w.entity;
    return w;
}

static void elements(void)
{
    World w = make_world();
    NSArray *properties = @[w.name, w.lat, w.flt, w.i16, w.i32, w.i64, w.dec, w.flag, w.date, w.data, w.rel, w.fetched];
    for (NSPropertyDescription *property in properties)
        for (NSInteger collation = 0; collation <= 1; collation++)
            CHECK_EQUAL(raised(^{ make_element((Kit){YES}, property, collation); }), raised(^{ make_element((Kit){NO}, property, collation); }), label(@"element %@ collation %ld", property.name, (long)collation));
    CHECK_EQUAL(raised(^{ make_element((Kit){YES}, nil, 0); }), raised(^{ make_element((Kit){NO}, nil, 0); }), "element with no property");
    NSAttributeDescription *unnamed = [[NSAttributeDescription alloc] init];
    unnamed.attributeType = NSStringAttributeType;
    CHECK_EQUAL(raised(^{ make_element((Kit){YES}, unnamed, 0); }), raised(^{ make_element((Kit){NO}, unnamed, 0); }), "element with an unnamed property");
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        id element = make_element(kit, w.i16, 0);
        NSString *side = kit.ours ? @"ours" : @"system";
        CHECK([element property] == w.i16 && [[element propertyName] isEqual:@"i16"] && [element collationType] == 0 && [element isAscending] && [element indexDescription] == nil, label(@"%@ element defaults", side));
    }
}

static NSString *element_state(id element)
{
    return [NSString stringWithFormat:@"%@ %lu %d %@", [element propertyName], (unsigned long)[element collationType], [element isAscending], [element indexDescription] ? @"in" : @"out"];
}

static void indexes(void)
{
    World w = make_world();
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        NSString *side = kit.ours ? @"ours" : @"system";
        CHECK_EQUAL(raised(^{ make_index(kit, nil, @[make_element(kit, w.name, 0)]); }), @"NSInvalidArgumentException: Can't create an index with no name", label(@"%@ index without a name", side));
        id nilElements = make_index(kit, @"x", nil);
        CHECK([nilElements elements] == nil && [[nilElements name] isEqual:@"x"], label(@"%@ index without elements", side));
        id emptyElements = make_index(kit, @"x", @[]);
        CHECK([[emptyElements elements] count] == 0, label(@"%@ index with empty elements", side));
        id rt = make_element(kit, w.i16, 1), bn = make_element(kit, w.name, 0), rt2 = make_element(kit, w.flt, 1);
        CHECK_EQUAL(raised(^{ make_index(kit, @"x", @[rt, bn]); }), @"NSInvalidArgumentException: Can't mix and match collation types.", label(@"%@ mixed collation", side));
        CHECK_EQUAL(raised(^{ make_index(kit, @"x", @[rt, rt2]); }), @"ok", label(@"%@ two rtree elements", side));
        NSMutableArray *held = [NSMutableArray arrayWithObject:bn];
        id ix = make_index(kit, @"byname", held);
        [held removeAllObjects];
        CHECK([[ix elements] count] == 1 && [ix elements][0] == bn && [bn indexDescription] == ix && [ix entity] == nil && [ix partialIndexPredicate] == nil, label(@"%@ index holds its elements", side));
        id second = make_index(kit, @"other", @[bn]);
        CHECK([bn indexDescription] == second && [ix elements][0] == bn, label(@"%@ an element follows the last index it was given to", side));
        CHECK_EQUAL(raised(^{ [ix setName:nil]; }), @"NSInvalidArgumentException: Can't set an index name to nil", label(@"%@ set name nil", side));
        [ix setName:@""];
        CHECK([[ix name] isEqual:@""], label(@"%@ empty name", side));
        NSMutableString *mutable = [NSMutableString stringWithString:@"a"];
        [ix setName:mutable];
        [mutable appendString:@"b"];
        CHECK_EQUAL([ix name], @"ab", label(@"%@ name is kept, not copied", side));
        id n1 = make_element(kit, w.i32, 0);
        [ix setElements:@[n1]];
        CHECK([n1 indexDescription] == nil && [[ix elements] count] == 1 && [ix elements][0] == n1, label(@"%@ set elements does not link them", side));
        CHECK_EQUAL(raised(^{ [ix setElements:@[make_element(kit, w.i16, 0), make_element(kit, w.flt, 1)]]; }), @"NSInvalidArgumentException: Can't mix and match collation types.", label(@"%@ set mixed elements", side));
        [ix setElements:nil];
        CHECK([ix elements] == nil, label(@"%@ set elements nil", side));
        [ix setPartialIndexPredicate:[NSPredicate predicateWithFormat:@"name != nil"]];
        CHECK_EQUAL([[ix partialIndexPredicate] predicateFormat], @"name != nil", label(@"%@ partial predicate", side));
    }
}

static void collation_changes(void)
{
    World w = make_world();
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        NSMutableArray *out = [NSMutableArray array];
        id a = make_element(kit, w.i16, 0), b = make_element(kit, w.i32, 0);
        id two = make_index(kit, @"m", @[a, b]);
        (void)two;
        [out addObject:raised(^{ [a setCollationType:1]; })];
        [out addObject:element_state(a)];
        id c = make_element(kit, w.flt, 1);
        id one = make_index(kit, @"one", @[c]);
        (void)one;
        [out addObject:raised(^{ [c setCollationType:0]; })];
        [out addObject:raised(^{ [c setCollationType:1]; })];
        id d = make_element(kit, w.i16, 1), e = make_element(kit, w.i32, 1);
        id rtree = make_index(kit, @"r", @[d, e]);
        (void)rtree;
        [out addObject:raised(^{ [d setCollationType:0]; })];
        [out addObject:element_state(d)];
        id lone = make_element(kit, w.i16, 0);
        [out addObject:raised(^{ [lone setCollationType:1]; })];
        id str = make_element(kit, w.name, 0);
        id strIndex = make_index(kit, @"s", @[str]);
        (void)strIndex;
        [out addObject:raised(^{ [str setCollationType:1]; })];
        [out addObject:element_state(str)];
        [a setAscending:NO];
        [out addObject:element_state(a)];
        [rows addObject:out];
    }
    CHECK_EQUAL(rows[1], rows[0], "collation changes");
}

static void values(void)
{
    World w = make_world();
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        NSMutableArray *out = [NSMutableArray array];
        id a = make_element(kit, w.flt, 1), twin = make_element(kit, w.flt, 1), other = make_element(kit, w.name, 0);
        id cp = [a copy];
        [out addObject:[NSString stringWithFormat:@"copy %d %d %@", cp == a, [cp property] == w.flt, element_state(cp)]];
        [a setAscending:NO];
        [out addObject:[NSString stringWithFormat:@"copy of descending %@", element_state([a copy])]];
        [a setAscending:YES];
        [out addObject:[NSString stringWithFormat:@"equal %d %d %d %d", [twin isEqual:a], [twin hash] == [a hash], [other isEqual:a], [a isEqual:@"x"]]];
        [twin setAscending:NO];
        [out addObject:[NSString stringWithFormat:@"unequal %d", [twin isEqual:a]]];
        [out addObject:plain([a description])];
        [twin setAscending:YES];
        id m1 = make_index(kit, @"multi", @[twin, make_element(kit, w.i16, 1)]), m2 = make_index(kit, @"multi", @[[a copy], make_element(kit, w.i16, 1)]), m3 = make_index(kit, @"other", @[[a copy], make_element(kit, w.i16, 1)]);
        [out addObject:[NSString stringWithFormat:@"index equal %d %d %d", [m1 isEqual:m2], [m1 hash] == [m2 hash], [m1 isEqual:m3]]];
        id icp = [m1 copy];
        [out addObject:[NSString stringWithFormat:@"index copy %d %d %d", icp == m1, [icp elements][0] != [m1 elements][0], [[icp elements][0] indexDescription] == icp]];
        [out addObject:plain([m1 description])];
        [rows addObject:out];
    }
    CHECK_EQUAL(rows[1], rows[0], "copies, equality and descriptions");
}

static void entities(void)
{
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        World w = make_world();
        NSMutableArray *out = [NSMutableArray array];
        NSEntityDescription *e = w.entity;
        NSArray *(^get)(void) = ^NSArray *{ return kit.ours ? [e charonHostindexes] : [e indexes]; };
        void (^set)(NSArray *) = ^(NSArray *x) { if (kit.ours) [e charonHostsetIndexes:x]; else [e setIndexes:x]; };
        [out addObject:[NSString stringWithFormat:@"default %lu", (unsigned long)get().count]];
        id a = make_element(kit, w.name, 0), b = make_element(kit, w.i16, 1);
        id ix = make_index(kit, @"byname", @[a]), ix2 = make_index(kit, @"byi16", @[b]);
        [out addObject:raised(^{ set(@[ix, ix2]); })];
        [out addObject:[NSString stringWithFormat:@"set %lu %d %d %d", (unsigned long)get().count, [ix entity] == e, [ix2 entity] == e, get()[0] == ix]];
        [out addObject:[NSString stringWithFormat:@"copy of an attached index %d", [[ix copy] entity] == e]];
        id dupe = make_index(kit, @"byname", @[make_element(kit, w.i32, 0)]);
        [out addObject:plain(raised(^{ set(@[ix, dupe]); }))];
        NSAttributeDescription *foreign = attribute(@"zzz", NSStringAttributeType);
        id fx = make_index(kit, @"f", @[make_element(kit, foreign, 0)]);
        [out addObject:raised(^{ set(@[fx]); })];
        NSRelationshipDescription *foreignRel = [[NSRelationshipDescription alloc] init];
        foreignRel.name = @"nowhere";
        id rx = make_index(kit, @"r", @[make_element(kit, foreignRel, 0)]);
        [out addObject:raised(^{ set(@[rx]); })];
        id relIndex = make_index(kit, @"viarel", @[make_element(kit, w.rel, 0)]);
        [out addObject:raised(^{ set(@[relIndex]); })];
        [out addObject:raised(^{ set(nil); }) ];
        [out addObject:[NSString stringWithFormat:@"after nil %lu %d", (unsigned long)get().count, [relIndex entity] == e]];
        NSExpression *expression = [NSExpression expressionForKeyPath:@"name"];
        [out addObject:[NSString stringWithFormat:@"expression default %d", (kit.ours ? [e charonHostcoreSpotlightDisplayNameExpression] : [e coreSpotlightDisplayNameExpression]) == nil]];
        if (kit.ours)
            [e charonHostsetCoreSpotlightDisplayNameExpression:expression];
        else
            [e setCoreSpotlightDisplayNameExpression:expression];
        [out addObject:[NSString stringWithFormat:@"expression set %d", (kit.ours ? [e charonHostcoreSpotlightDisplayNameExpression] : [e coreSpotlightDisplayNameExpression]) == expression]];
        NSEntityDescription *frozen = [[NSEntityDescription alloc] init];
        frozen.name = @"Frozen";
        frozen.properties = @[attribute(@"name", NSStringAttributeType)];
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
        model.entities = @[frozen];
        (void)[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        [out addObject:raised(^{ if (kit.ours) [frozen charonHostsetIndexes:@[]]; else [frozen setIndexes:@[]]; })];
        [out addObject:raised(^{ if (kit.ours) [frozen charonHostsetCoreSpotlightDisplayNameExpression:nil]; else [frozen setCoreSpotlightDisplayNameExpression:nil]; })];
        [rows addObject:out];
    }
    CHECK_EQUAL(rows[1], rows[0], "entity indexes");
}

static void coding(void)
{
    World w = make_world();
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        Kit kit = {i == 1};
        id a = make_element(kit, w.i16, 1);
        id ix = make_index(kit, @"byi16", @[a]);
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [archiver encodeObject:ix forKey:@"root"];
        [archiver finishEncoding];
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archiver.encodedData options:0 format:NULL error:NULL];
        NSMutableArray *keys = [NSMutableArray array];
        for (id object in plist[@"$objects"])
            if ([object isKindOfClass:[NSDictionary class]] && ([object objectForKey:@"NSIndexName"] || [object objectForKey:@"NSPropertyName"]))
                [keys addObject:[[[object allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH '$'"]] sortedArrayUsingSelector:@selector(compare:)]];
        [rows addObject:keys];
    }
    CHECK_EQUAL(rows[1], rows[0], "the keys of an archive");
    Kit ours = {YES};
    id a = make_element(ours, w.i16, 1);
    id ix = make_index(ours, @"byi16", @[a]);
    [ix setPartialIndexPredicate:[NSPredicate predicateWithFormat:@"i16 > 1"]];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    [archiver encodeObject:ix forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = YES;
    id back = [unarchiver decodeObjectOfClass:index_class(ours) forKey:@"root"];
    CHECK(back != nil && [[back name] isEqual:@"byi16"] && [[back elements] count] == 1 && [[[back elements][0] propertyName] isEqual:@"i16"] && [[back elements][0] collationType] == 1 && [[[back partialIndexPredicate] predicateFormat] isEqual:@"i16 > 1"], "an archive round trip");
}

int main(void)
{
    @autoreleasepool {
        elements();
        indexes();
        collation_changes();
        values();
        entities();
        coding();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
