#import "../Foundation/check.h"
#import <Intents/Intents.h>
#import <objc/message.h>

static id revenant_init_object(Class cls, NSString *identifier, NSString *display, NSString *pronunciation)
{
    id object = [cls alloc];
    return [object initWithIdentifier:identifier displayString:display pronunciationHint:pronunciation];
}

static id revenant_init_object_subtitle(Class cls, NSString *identifier, NSString *display, NSString *subtitle)
{
    id object = [cls alloc];
    return [object initWithIdentifier:identifier displayString:display subtitleString:subtitle displayImage:nil];
}

static id revenant_init_section(Class cls, NSString *title, NSArray *items)
{
    id section = [cls alloc];
    return [section initWithTitle:title items:items];
}

static id revenant_init_collection_items(Class cls, NSArray *items)
{
    id collection = [cls alloc];
    return [collection initWithItems:items];
}

static id revenant_init_collection_sections(Class cls, NSArray *sections)
{
    id collection = [cls alloc];
    return [collection initWithSections:sections];
}

static id revenant_round_trip(id value)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&error];
    revenant_check(data != nil && error == nil, "secure archiving succeeds", error.localizedDescription ?: @"no data");
    id decoded = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:[value class] fromData:data error:&error] : nil;
    revenant_check(decoded != nil && error == nil, "secure unarchiving succeeds", error.localizedDescription ?: @"no decoded object");
    return decoded;
}

static void revenant_compare_value(NSString *key, id host, id backport)
{
    id expected = [host valueForKey:key];
    id actual = [backport valueForKey:key];
    revenant_check(expected == actual || [expected isEqual:actual], [key UTF8String], [NSString stringWithFormat:@"%@ != %@", expected, actual]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class objectClass = NSClassFromString(@"INObjectRevenant");
    Class sectionClass = NSClassFromString(@"INObjectSectionRevenant");
    Class collectionClass = NSClassFromString(@"INObjectCollectionRevenant");
    revenant_check((objectClass != Nil) != revenant_negative, "INObject implementation is present", NSStringFromClass(objectClass));
    revenant_check(sectionClass != Nil, "INObjectSection implementation is present", NSStringFromClass(sectionClass));
    revenant_check(collectionClass != Nil, "INObjectCollection implementation is present", NSStringFromClass(collectionClass));
    if (!objectClass || !sectionClass || !collectionClass)
        return revenant_finish();

    INObject *hostAda = [[INObject alloc] initWithIdentifier:@"ada" displayString:@"Ada Lovelace" pronunciationHint:@"AY-duh"];
    id backportAda = revenant_init_object(objectClass, @"ada", @"Ada Lovelace", @"AY-duh");
    revenant_compare_value(@"identifier", hostAda, backportAda);
    revenant_compare_value(@"displayString", hostAda, backportAda);
    revenant_compare_value(@"pronunciationHint", hostAda, backportAda);
    revenant_compare_value(@"spokenPhrase", hostAda, backportAda);
    revenant_compare_value(@"vocabularyIdentifier", hostAda, backportAda);
    revenant_compare_value(@"subtitleString", hostAda, backportAda);
    revenant_compare_value(@"displayImage", hostAda, backportAda);
    revenant_compare_value(@"alternativeSpeakableMatches", hostAda, backportAda);

    INObject *hostGrace = [[INObject alloc] initWithIdentifier:@"grace" displayString:@"Grace Hopper" subtitleString:@"Navy" displayImage:nil];
    id backportGrace = revenant_init_object_subtitle(objectClass, @"grace", @"Grace Hopper", @"Navy");
    revenant_compare_value(@"identifier", hostGrace, backportGrace);
    revenant_compare_value(@"displayString", hostGrace, backportGrace);
    revenant_compare_value(@"pronunciationHint", hostGrace, backportGrace);
    revenant_compare_value(@"subtitleString", hostGrace, backportGrace);
    revenant_compare_value(@"displayImage", hostGrace, backportGrace);

    INObject *hostShort = [[INObject alloc] initWithIdentifier:nil displayString:@"Anonymous"];
    id backportShort = [[objectClass alloc] initWithIdentifier:nil displayString:@"Anonymous"];
    revenant_compare_value(@"identifier", hostShort, backportShort);
    revenant_compare_value(@"pronunciationHint", hostShort, backportShort);

    revenant_check([hostAda isEqual:[hostAda copy]] == [backportAda isEqual:[backportAda copy]], "object copy equality matches host", [NSString stringWithFormat:@"%@ %@", hostAda, backportAda]);
    INObject *hostOther = [[INObject alloc] initWithIdentifier:@"ada" displayString:@"Countess" pronunciationHint:nil];
    id backportOther = revenant_init_object(objectClass, @"ada", @"Countess", nil);
    revenant_check([hostAda isEqual:hostOther] == [backportAda isEqual:backportOther], "object inequality matches host", [NSString stringWithFormat:@"%@ %@", hostOther, backportOther]);
    revenant_check([backportAda isEqual:[backportAda copy]], "object copy equals original", NSStringFromClass([backportAda class]));
    revenant_check([backportAda hash] == [[backportAda copy] hash], "object copy hash matches original", NSStringFromClass([backportAda class]));

    id decodedAda = revenant_round_trip(backportAda);
    revenant_check(decodedAda && [backportAda isEqual:decodedAda], "object secure coding preserves value", [NSString stringWithFormat:@"%@", decodedAda]);
    id decodedGrace = revenant_round_trip(backportGrace);
    revenant_expect_string("object subtitle survives secure coding", [decodedGrace valueForKey:@"subtitleString"], @"Navy");

    INObjectSection *hostSection = [[INObjectSection alloc] initWithTitle:@"Friends" items:@[hostAda, hostGrace]];
    id backportSection = revenant_init_section(sectionClass, @"Friends", @[backportAda, backportGrace]);
    revenant_compare_value(@"title", hostSection, backportSection);
    revenant_check([[hostSection items] count] == [[backportSection valueForKey:@"items"] count], "section item count matches host", [NSString stringWithFormat:@"%@", backportSection]);
    id decodedSection = revenant_round_trip(backportSection);
    revenant_check(decodedSection && [backportSection isEqual:decodedSection], "section secure coding preserves value", [NSString stringWithFormat:@"%@", decodedSection]);

    id untitled = revenant_init_section(sectionClass, nil, @[backportAda]);
    INObjectSection *hostUntitled = [[INObjectSection alloc] initWithTitle:nil items:@[hostAda]];
    revenant_compare_value(@"title", hostUntitled, untitled);

    INObjectCollection *hostItems = [[INObjectCollection alloc] initWithItems:@[hostAda, hostGrace]];
    id backportItems = revenant_init_collection_items(collectionClass, @[backportAda, backportGrace]);
    revenant_check([[hostItems sections] count] == [[backportItems valueForKey:@"sections"] count], "items collection section count matches host", [NSString stringWithFormat:@"%@", backportItems]);
    revenant_compare_value(@"title", [hostItems sections].firstObject, [[backportItems valueForKey:@"sections"] firstObject]);
    revenant_check([[hostItems allItems] count] == [[backportItems valueForKey:@"allItems"] count], "items collection item count matches host", [NSString stringWithFormat:@"%@", backportItems]);
    revenant_compare_value(@"usesIndexedCollation", hostItems, backportItems);
    [hostItems setUsesIndexedCollation:YES];
    [backportItems setValue:@YES forKey:@"usesIndexedCollation"];
    revenant_compare_value(@"usesIndexedCollation", hostItems, backportItems);
    NSArray *backportAllItems = [backportItems valueForKey:@"allItems"];
    revenant_expect_string("items collection keeps order", [backportAllItems.firstObject valueForKey:@"displayString"], @"Ada Lovelace");
    revenant_expect_string("items collection keeps last item", [backportAllItems.lastObject valueForKey:@"displayString"], @"Grace Hopper");

    INObjectCollection *hostSections = [[INObjectCollection alloc] initWithSections:@[hostSection, [[INObjectSection alloc] initWithTitle:@"Family" items:@[hostAda]]]];
    id backportSections = revenant_init_collection_sections(collectionClass, @[backportSection, revenant_init_section(sectionClass, @"Family", @[backportAda])]);
    revenant_check([[hostSections sections] count] == [[backportSections valueForKey:@"sections"] count], "sections collection count matches host", [NSString stringWithFormat:@"%@", backportSections]);
    revenant_check([[hostSections allItems] count] == [[backportSections valueForKey:@"allItems"] count], "sections collection flattens items like host", [NSString stringWithFormat:@"%@", backportSections]);
    revenant_check([[backportSections valueForKey:@"usesIndexedCollation"] boolValue] == NO, "sections collection defaults to no indexed collation", [NSString stringWithFormat:@"%@", backportSections]);
    id decodedCollection = revenant_round_trip(backportSections);
    revenant_check(decodedCollection && [backportSections isEqual:decodedCollection], "collection secure coding preserves value", [NSString stringWithFormat:@"%@", decodedCollection]);

    return revenant_finish();
}
