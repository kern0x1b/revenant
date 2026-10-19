#import <Foundation/Foundation.h>
#import "personname-cases.h"

static NSString *fields(NSPersonNameComponents *c)
{
    return [NSString stringWithFormat:@"prefix=%@ given=%@ middle=%@ family=%@ suffix=%@ nickname=%@ phonetic=%d", c.namePrefix, c.givenName, c.middleName, c.familyName, c.nameSuffix, c.nickname, c.phoneticRepresentation != nil];
}

static NSString *stripped(NSString *description)
{
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    return [pointer stringByReplacingMatchesInString:description options:0 range:NSMakeRange(0, description.length) withTemplate:@"0x"];
}

void personname_run(PersonNameRecorder record)
{
    NSPersonNameComponents *empty = [[NSPersonNameComponents alloc] init];
    record(@"empty", [NSString stringWithFormat:@"%@ super=%@", fields(empty), NSStringFromClass([empty superclass])]);
    NSPersonNameComponents *name = [[NSPersonNameComponents alloc] init];
    name.namePrefix = @"Dr.";
    name.givenName = @"Ada";
    NSMutableString *middle = [NSMutableString stringWithString:@"Augusta"];
    name.middleName = middle;
    [middle appendString:@" King"];
    name.familyName = @"Lovelace";
    name.nameSuffix = @"Esq.";
    name.nickname = @"Countess";
    record(@"set", fields(name));
    record(@"middleCopied", name.middleName);
    NSPersonNameComponents *phonetic = [[NSPersonNameComponents alloc] init];
    phonetic.givenName = @"AY-duh";
    name.phoneticRepresentation = phonetic;
    record(@"phoneticKept", [NSString stringWithFormat:@"%d", name.phoneticRepresentation == phonetic]);
    NSPersonNameComponents *copy = [name copy];
    record(@"copy", [NSString stringWithFormat:@"same=%d equal=%d hash=%d %@ phoneticShared=%d", copy == name, [copy isEqual:name], copy.hash == name.hash, fields(copy), copy.phoneticRepresentation == phonetic]);
    copy.givenName = @"Augusta";
    record(@"copyChanged", [NSString stringWithFormat:@"equal=%d original=%@", [copy isEqual:name], name.givenName]);
    record(@"equalEmpty", [NSString stringWithFormat:@"%d %d", [empty isEqual:[[NSPersonNameComponents alloc] init]], [name isEqual:empty]]);
    NSPersonNameComponents *deep = [[NSPersonNameComponents alloc] init];
    deep.phoneticRepresentation = phonetic;
    NSPersonNameComponents *other = [[NSPersonNameComponents alloc] init];
    NSPersonNameComponents *otherPhonetic = [[NSPersonNameComponents alloc] init];
    otherPhonetic.givenName = @"AY-duh";
    other.phoneticRepresentation = otherPhonetic;
    record(@"equalPhonetic", [NSString stringWithFormat:@"%d", [deep isEqual:other]]);
    record(@"protocols", [NSString stringWithFormat:@"secure=%d copying=%d", [name conformsToProtocol:@protocol(NSSecureCoding)], [name conformsToProtocol:@protocol(NSCopying)]]);
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:name];
    NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    reader.requiresSecureCoding = YES;
    NSPersonNameComponents *decoded = [reader decodeObjectOfClass:[NSPersonNameComponents class] forKey:NSKeyedArchiveRootObjectKey];
    record(@"coding", [NSString stringWithFormat:@"%@ equal=%d phoneticGiven=%@", fields(decoded), [decoded isEqual:name], decoded.phoneticRepresentation.givenName]);
    name.givenName = nil;
    name.phoneticRepresentation = nil;
    record(@"cleared", fields(name));
    record(@"description", stripped([empty description]));
    NSPersonNameComponents *described = [[NSPersonNameComponents alloc] init];
    described.givenName = @"Ada";
    described.familyName = @"Lovelace";
    described.nickname = @"A";
    record(@"descriptionSet", stripped([described description]));
    NSPersonNameComponents *nested = [[NSPersonNameComponents alloc] init];
    nested.givenName = @"E";
    described.phoneticRepresentation = nested;
    record(@"descriptionNested", stripped([described description]));
}
