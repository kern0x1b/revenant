#import <CoreData/CoreData.h>
#import <dlfcn.h>
#import <objc/message.h>
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

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"ok";
}

static NSAttributeDescription *attribute(NSString *name, NSAttributeType type)
{
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = type;
    a.optional = YES;
    return a;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of((__bridge void *)[NSFetchIndexDescription class]), @"libCoreDataBackports.dylib", "the index description comes from the backports");
        CHECK_EQUAL(image_of((__bridge void *)[NSFetchIndexElementDescription class]), @"libCoreDataBackports.dylib", "the index element comes from the backports");
        NSAttributeDescription *name = attribute(@"name", NSStringAttributeType), *lat = attribute(@"lat", NSDoubleAttributeType), *flt = attribute(@"flt", NSFloatAttributeType);
        NSAttributeDescription *i16 = attribute(@"i16", NSInteger16AttributeType), *i32 = attribute(@"i32", NSInteger32AttributeType), *i64 = attribute(@"i64", NSInteger64AttributeType);
        NSRelationshipDescription *rel = [[NSRelationshipDescription alloc] init];
        rel.name = @"rel";
        rel.maxCount = 1;
        rel.optional = YES;
        NSFetchedPropertyDescription *fetched = [[NSFetchedPropertyDescription alloc] init];
        fetched.name = @"fetched";
        NSEntityDescription *entity = [[NSEntityDescription alloc] init];
        entity.name = @"E";
        entity.properties = @[name, lat, flt, i16, i32, i64, rel];
        rel.destinationEntity = entity;

        NSString *onAttributes = @"NSInvalidArgumentException: Invalid collation type (rtree indexes can only be created on attributes).";
        NSString *onNumbers = @"NSInvalidArgumentException: Invalid collation type (rtree indexes can only be created for floats or integers < 32 bit).";
        for (NSAttributeDescription *a in @[name, lat, i64])
            CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:a collationType:NSFetchIndexElementTypeRTree]; }), onNumbers, label(@"an rtree element refuses %@", a.name));
        for (NSAttributeDescription *a in @[flt, i16, i32])
            CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:a collationType:NSFetchIndexElementTypeRTree]; }), @"ok", label(@"an rtree element takes %@", a.name));
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:rel collationType:NSFetchIndexElementTypeRTree]; }), onAttributes, "an rtree element refuses a relationship");
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:rel collationType:NSFetchIndexElementTypeBinary]; }), @"ok", "a binary element takes a relationship");
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:nil collationType:NSFetchIndexElementTypeBinary]; }), @"NSInvalidArgumentException: Can't create an index element without a property", "an element needs a property");
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:fetched collationType:NSFetchIndexElementTypeBinary]; }), @"NSInvalidArgumentException: Can't create an index element with non-attribute property", "a fetched property is refused");
        NSAttributeDescription *unnamed = [[NSAttributeDescription alloc] init];
        unnamed.attributeType = NSStringAttributeType;
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexElementDescription alloc] initWithProperty:unnamed collationType:NSFetchIndexElementTypeBinary]; }), @"NSInvalidArgumentException: Can't create an index element with an unnamed property", "and so is an unnamed one");

        NSFetchIndexElementDescription *element = [[NSFetchIndexElementDescription alloc] initWithProperty:i16 collationType:NSFetchIndexElementTypeBinary];
        CHECK(element.property == i16 && [element.propertyName isEqual:@"i16"] && element.collationType == NSFetchIndexElementTypeBinary && element.isAscending && element.indexDescription == nil, "an element starts ascending, in no index");
        NSFetchIndexElementDescription *bn = [[NSFetchIndexElementDescription alloc] initWithProperty:name collationType:NSFetchIndexElementTypeBinary];
        NSFetchIndexElementDescription *rt = [[NSFetchIndexElementDescription alloc] initWithProperty:i16 collationType:NSFetchIndexElementTypeRTree];
        NSFetchIndexElementDescription *rt2 = [[NSFetchIndexElementDescription alloc] initWithProperty:flt collationType:NSFetchIndexElementTypeRTree];
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexDescription alloc] initWithName:nil elements:@[bn]]; }), @"NSInvalidArgumentException: Can't create an index with no name", "an index needs a name");
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexDescription alloc] initWithName:@"x" elements:@[rt, bn]]; }), @"NSInvalidArgumentException: Can't mix and match collation types.", "an index does not mix collation types");
        CHECK_EQUAL(raised(^{ (void)[[NSFetchIndexDescription alloc] initWithName:@"x" elements:@[rt, rt2]]; }), @"ok", "and takes two rtree elements");
        NSFetchIndexDescription *byName = [[NSFetchIndexDescription alloc] initWithName:@"byname" elements:@[bn]];
        CHECK(byName.elements.count == 1 && byName.elements[0] == bn && bn.indexDescription == byName && byName.entity == nil && byName.partialIndexPredicate == nil, "an index holds its elements");
        CHECK_EQUAL(raised(^{ byName.name = nil; }), @"NSInvalidArgumentException: Can't set an index name to nil", "its name cannot be nil");
        CHECK_EQUAL(raised(^{ rt.collationType = NSFetchIndexElementTypeBinary; }), @"ok", "an element in no index changes its collation");
        NSFetchIndexElementDescription *alone = [[NSFetchIndexElementDescription alloc] initWithProperty:flt collationType:NSFetchIndexElementTypeRTree];
        NSFetchIndexDescription *single = [[NSFetchIndexDescription alloc] initWithName:@"single" elements:@[alone]];
        CHECK_EQUAL(raised(^{ alone.collationType = NSFetchIndexElementTypeBinary; }), @"NSInvalidArgumentException: Can't change an collation type in a multi-element index", "the only element of an index cannot change its collation");
        CHECK(single != nil, "and the index is still there");
        NSFetchIndexElementDescription *a2 = [[NSFetchIndexElementDescription alloc] initWithProperty:i16 collationType:NSFetchIndexElementTypeRTree], *b2 = [[NSFetchIndexElementDescription alloc] initWithProperty:i32 collationType:NSFetchIndexElementTypeRTree];
        NSFetchIndexDescription *pair = [[NSFetchIndexDescription alloc] initWithName:@"pair" elements:@[a2, b2]];
        CHECK_EQUAL(raised(^{ a2.collationType = NSFetchIndexElementTypeBinary; }), @"ok", "one of two elements can");
        CHECK(pair != nil && a2.collationType == NSFetchIndexElementTypeBinary, "and does");
        NSFetchIndexElementDescription *twin = [[NSFetchIndexElementDescription alloc] initWithProperty:name collationType:NSFetchIndexElementTypeBinary];
        CHECK([twin isEqual:bn] && twin.hash == bn.hash && twin != bn, "elements of one property and setting are equal");
        NSFetchIndexElementDescription *copy = [bn copy];
        CHECK(copy != bn && copy.property == name && copy.indexDescription == nil && copy.isAscending, "a copy is a new element in no index");
        CHECK_EQUAL(bn.description, @"<NSFetchIndexElementDescription : (name (modeled property), 0, ascending)>", "the description of an element");
        bn.ascending = NO;
        CHECK_EQUAL(bn.description, @"<NSFetchIndexElementDescription : (name (modeled property), 0, descending)>", "and of a descending one");
        bn.ascending = YES;

        CHECK(entity.indexes != nil && entity.indexes.count == 0 && entity.coreSpotlightDisplayNameExpression == nil, "a new entity has no indexes and no display name");
        NSFetchIndexElementDescription *e1 = [[NSFetchIndexElementDescription alloc] initWithProperty:name collationType:NSFetchIndexElementTypeBinary];
        NSFetchIndexElementDescription *e2 = [[NSFetchIndexElementDescription alloc] initWithProperty:i16 collationType:NSFetchIndexElementTypeRTree];
        NSFetchIndexDescription *ix1 = [[NSFetchIndexDescription alloc] initWithName:@"byname" elements:@[e1]], *ix2 = [[NSFetchIndexDescription alloc] initWithName:@"byi16" elements:@[e2]];
        entity.indexes = @[ix1, ix2];
        CHECK(entity.indexes.count == 2 && entity.indexes[0] == ix1 && ix1.entity == entity && ix2.entity == entity, "an entity holds its indexes and they know it");
        CHECK_EQUAL(ix1.description, @"<NSFetchIndexDescription : (E:byname, elements: (\n    \"<NSFetchIndexElementDescription : (name (modeled property), 0, ascending)>\"\n), predicate: (null))>", "the description of an index");
        CHECK([[ix1 copy] entity] == entity, "a copy of an attached index has the entity");
        NSFetchIndexDescription *dupe = [[NSFetchIndexDescription alloc] initWithName:@"byname" elements:@[[[NSFetchIndexElementDescription alloc] initWithProperty:i32 collationType:NSFetchIndexElementTypeBinary]]];
        CHECK_EQUAL(raised(^{ entity.indexes = @[ix1, dupe]; }), @"NSInvalidArgumentException: Entity E already has an index with name byname", "two indexes of one name are refused");
        NSFetchIndexDescription *foreign = [[NSFetchIndexDescription alloc] initWithName:@"f" elements:@[[[NSFetchIndexElementDescription alloc] initWithProperty:attribute(@"zzz", NSStringAttributeType) collationType:NSFetchIndexElementTypeBinary]]];
        CHECK_EQUAL(raised(^{ entity.indexes = @[foreign]; }), @"NSInvalidArgumentException: can't find attribute named zzz", "an attribute the entity does not have is refused");
        NSRelationshipDescription *other = [[NSRelationshipDescription alloc] init];
        other.name = @"nowhere";
        NSFetchIndexDescription *viaRelationship = [[NSFetchIndexDescription alloc] initWithName:@"r" elements:@[[[NSFetchIndexElementDescription alloc] initWithProperty:other collationType:NSFetchIndexElementTypeBinary]]];
        CHECK_EQUAL(raised(^{ entity.indexes = @[viaRelationship]; }), @"NSInvalidArgumentException: can't find relationship named nowhere", "and so is a relationship");
        entity.indexes = nil;
        CHECK(entity.indexes.count == 0, "nil clears the indexes");
        NSExpression *expression = [NSExpression expressionForKeyPath:@"name"];
        entity.coreSpotlightDisplayNameExpression = expression;
        CHECK(entity.coreSpotlightDisplayNameExpression == expression, "the display name expression is kept");

        NSEntityDescription *frozen = [[NSEntityDescription alloc] init];
        frozen.name = @"Frozen";
        frozen.properties = @[attribute(@"name", NSStringAttributeType)];
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
        model.entities = @[frozen];
        (void)[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        CHECK_EQUAL(raised(^{ frozen.indexes = @[]; }), @"NSInternalInconsistencyException: Can't modify an immutable model.", "the indexes of an entity of a model in use cannot change");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
