#import "../Foundation/check.h"
#import <Intents/Intents.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSArray<NSString *> *revenant_keys(void)
{
    return @[@"identifier", @"dateCreated", @"callRecordType", @"callCapability", @"callDuration", @"unseen", @"participants", @"numberOfCalls", @"isCallerIdBlocked"];
}

static INPerson *revenant_person(NSString *name)
{
    INPersonHandle *handle = [[INPersonHandle alloc] initWithValue:name type:INPersonHandleTypeUnknown];
    return [[INPerson alloc] initWithPersonHandle:handle nameComponents:nil displayName:name image:nil contactIdentifier:nil customIdentifier:name];
}

static id revenant_full(Class cls, NSString *identifier, NSDate *date, INCallRecordType type, INCallCapability capability, NSNumber *duration, NSNumber *unseen, NSArray *participants, NSNumber *count, NSNumber *blocked)
{
    id record = [cls alloc];
    return [record initWithIdentifier:identifier dateCreated:date callRecordType:type callCapability:capability callDuration:duration unseen:unseen participants:participants numberOfCalls:count isCallerIdBlocked:blocked];
}

static void revenant_compare(const char *context, id host, id backport)
{
    for (NSString *key in revenant_keys()) {
        id expected = [host valueForKey:key];
        id actual = [backport valueForKey:key];
        NSString *name = [NSString stringWithFormat:@"%s %@", context, key];
        revenant_check(expected == actual || [expected isEqual:actual], [name UTF8String], [NSString stringWithFormat:@"%@ != %@", expected, actual]);
    }
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

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class recordClass = NSClassFromString(@"INCallRecordRevenant");
    revenant_check((recordClass != Nil) != revenant_negative, "INCallRecord implementation is present", NSStringFromClass(recordClass));
    if (!recordClass)
        return revenant_finish();

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSArray *people = @[revenant_person(@"ada"), revenant_person(@"grace")];

    id host = [[INCallRecord alloc] initWithIdentifier:@"call" dateCreated:date callRecordType:INCallRecordTypeMissed callCapability:INCallCapabilityVideoCall callDuration:@42.5 unseen:@YES participants:people numberOfCalls:@3 isCallerIdBlocked:@NO];
    id backport = revenant_full(recordClass, @"call", date, INCallRecordTypeMissed, INCallCapabilityVideoCall, @42.5, @YES, people, @3, @NO);
    revenant_compare("designated", host, backport);

    id hostBare = [[INCallRecord alloc] initWithIdentifier:@"bare" dateCreated:nil callRecordType:INCallRecordTypeUnknown callCapability:INCallCapabilityUnknown callDuration:nil unseen:nil participants:nil numberOfCalls:nil isCallerIdBlocked:nil];
    id backportBare = revenant_full(recordClass, @"bare", nil, INCallRecordTypeUnknown, INCallCapabilityUnknown, nil, nil, nil, nil, nil);
    revenant_compare("bare", hostBare, backportBare);

    id hostCount = [[INCallRecord alloc] initWithIdentifier:@"count" dateCreated:date callRecordType:INCallRecordTypeOutgoing callCapability:INCallCapabilityAudioCall callDuration:@7 unseen:@NO numberOfCalls:@2];
    id backportCount = [[recordClass alloc] initWithIdentifier:@"count" dateCreated:date callRecordType:INCallRecordTypeOutgoing callCapability:INCallCapabilityAudioCall callDuration:@7 unseen:@NO numberOfCalls:@2];
    revenant_compare("numberOfCalls initializer", hostCount, backportCount);

    id hostCaller = [[INCallRecord alloc] initWithIdentifier:@"caller" dateCreated:date caller:people[0] callRecordType:INCallRecordTypeReceived callCapability:INCallCapabilityAudioCall callDuration:@9 unseen:@YES numberOfCalls:@1];
    id backportCaller = [[recordClass alloc] initWithIdentifier:@"caller" dateCreated:date caller:people[0] callRecordType:INCallRecordTypeReceived callCapability:INCallCapabilityAudioCall callDuration:@9 unseen:@YES numberOfCalls:@1];
    revenant_compare("caller initializer", hostCaller, backportCaller);
    revenant_check([[backportCaller valueForKey:@"caller"] isEqual:[hostCaller valueForKey:@"caller"]], "caller is the first participant", [[backportCaller valueForKey:@"caller"] description]);

    id hostNoCaller = [[INCallRecord alloc] initWithIdentifier:@"nocaller" dateCreated:date caller:nil callRecordType:INCallRecordTypeReceived callCapability:INCallCapabilityAudioCall callDuration:nil unseen:nil];
    id backportNoCaller = [[recordClass alloc] initWithIdentifier:@"nocaller" dateCreated:date caller:nil callRecordType:INCallRecordTypeReceived callCapability:INCallCapabilityAudioCall callDuration:nil unseen:nil];
    revenant_compare("caller initializer without a caller", hostNoCaller, backportNoCaller);

    id restored = revenant_round_trip(backport);
    revenant_check([restored isKindOfClass:recordClass], "the decoded record has the record class", NSStringFromClass([restored class]));
    revenant_compare("decoded", host, restored);
    revenant_check([restored isEqual:backport] && [backport isEqual:restored], "a decoded record equals the original", [restored description]);
    revenant_check([restored hash] == [backport hash], "a decoded record hashes like the original", @"hash differs");

    id copy = [backport copy];
    revenant_check([copy isKindOfClass:recordClass] && [copy isEqual:backport] && [copy hash] == [backport hash], "a copy equals the original", [copy description]);
    revenant_compare("copy", host, copy);

    revenant_check(![backport isEqual:backportBare], "records with other fields differ", @"equal");
    revenant_check(![backport isEqual:nil] && ![backport isEqual:@"call"], "a record is not equal to nil or a string", @"equal");
    id other = revenant_full(recordClass, @"call", date, INCallRecordTypeMissed, INCallCapabilityVideoCall, @42.5, @YES, people, @4, @NO);
    revenant_check(![backport isEqual:other], "a different number of calls differs", @"equal");
    other = revenant_full(recordClass, @"call", date, INCallRecordTypeReceived, INCallCapabilityVideoCall, @42.5, @YES, people, @3, @NO);
    revenant_check(![backport isEqual:other], "a different record type differs", @"equal");
    other = revenant_full(recordClass, @"call", date, INCallRecordTypeMissed, INCallCapabilityVideoCall, @42.5, @YES, people, @3, @NO);
    revenant_check([backport isEqual:other] && [backport hash] == [other hash], "records built from the same values are equal", @"differ");

    revenant_check([recordClass supportsSecureCoding], "the record supports secure coding", @"no");
    return revenant_finish();
}
