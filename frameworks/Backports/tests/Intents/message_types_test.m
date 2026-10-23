#import "../Foundation/check.h"
#import <Intents/Intents.h>
#import <objc/message.h>

static id revenant_init_handle(Class cls, NSString *value, INPersonHandleType type, INPersonHandleLabel label)
{
    id handle = [cls alloc];
    return [handle initWithValue:value type:type label:label];
}

static id revenant_init_person(Class cls, id handle, NSString *displayName, NSString *contactIdentifier, NSString *customIdentifier)
{
    id person = [cls alloc];
    return [person initWithPersonHandle:handle nameComponents:nil displayName:displayName image:nil contactIdentifier:contactIdentifier customIdentifier:customIdentifier];
}

static id revenant_init_message(Class cls, NSArray *recipients, INOutgoingMessageType type, NSString *content, NSString *conversationIdentifier, NSString *serviceName, id sender)
{
    id message = [cls alloc];
    return [message initWithRecipients:recipients outgoingMessageType:type content:content speakableGroupName:nil conversationIdentifier:conversationIdentifier serviceName:serviceName sender:sender attachments:nil];
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
    Class handleClass = NSClassFromString(@"INPersonHandleRevenant");
    Class personClass = NSClassFromString(@"INPersonRevenant");
    Class messageClass = NSClassFromString(@"INSendMessageIntentRevenant");
    revenant_check((handleClass != Nil) != revenant_negative, "INPersonHandle implementation is present", NSStringFromClass(handleClass));
    revenant_check(personClass != Nil, "INPerson implementation is present", NSStringFromClass(personClass));
    revenant_check(messageClass != Nil, "INSendMessageIntent implementation is present", NSStringFromClass(messageClass));
    if (!handleClass || !personClass || !messageClass)
        return revenant_finish();

    INPersonHandle *hostHandle = [[INPersonHandle alloc] initWithValue:@"+48123456789" type:INPersonHandleTypePhoneNumber label:INPersonHandleLabelMobile];
    id backportHandle = revenant_init_handle(handleClass, @"+48123456789", INPersonHandleTypePhoneNumber, INPersonHandleLabelMobile);
    revenant_compare_value(@"value", hostHandle, backportHandle);
    revenant_compare_value(@"type", hostHandle, backportHandle);
    revenant_compare_value(@"label", hostHandle, backportHandle);
    revenant_check([hostHandle isEqual:[hostHandle copy]] == [backportHandle isEqual:[backportHandle copy]], "handle equality matches host", [NSString stringWithFormat:@"%@ %@", hostHandle, backportHandle]);
    id decodedHandle = revenant_round_trip(backportHandle);
    revenant_check(decodedHandle && [backportHandle isEqual:decodedHandle], "handle secure coding preserves equality", [NSString stringWithFormat:@"%@", decodedHandle]);

    INPerson *hostPerson = [[INPerson alloc] initWithPersonHandle:hostHandle nameComponents:nil displayName:@"Ada Lovelace" image:nil contactIdentifier:@"contact-1" customIdentifier:@"person-1"];
    id backportPerson = revenant_init_person(personClass, backportHandle, @"Ada Lovelace", @"contact-1", @"person-1");
    revenant_compare_value(@"displayName", hostPerson, backportPerson);
    revenant_compare_value(@"contactIdentifier", hostPerson, backportPerson);
    revenant_compare_value(@"customIdentifier", hostPerson, backportPerson);
    revenant_check([[[hostPerson personHandle] value] isEqualToString:[[backportPerson personHandle] value]], "person handle value matches host", [NSString stringWithFormat:@"%@", [backportPerson personHandle]]);
    revenant_check([hostPerson isEqual:[hostPerson copy]] == [backportPerson isEqual:[backportPerson copy]], "person equality matches host", [NSString stringWithFormat:@"%@ %@", hostPerson, backportPerson]);
    id decodedPerson = revenant_round_trip(backportPerson);
    revenant_check(decodedPerson && [backportPerson isEqual:decodedPerson], "person secure coding preserves equality", [NSString stringWithFormat:@"%@", decodedPerson]);

    INSendMessageIntent *hostMessage = [[INSendMessageIntent alloc] initWithRecipients:@[hostPerson] outgoingMessageType:INOutgoingMessageTypeOutgoingMessageText content:@"hello" speakableGroupName:nil conversationIdentifier:@"conversation-1" serviceName:@"Messages" sender:hostPerson attachments:nil];
    id backportMessage = revenant_init_message(messageClass, @[backportPerson], INOutgoingMessageTypeOutgoingMessageText, @"hello", @"conversation-1", @"Messages", backportPerson);
    revenant_compare_value(@"content", hostMessage, backportMessage);
    revenant_compare_value(@"conversationIdentifier", hostMessage, backportMessage);
    revenant_compare_value(@"serviceName", hostMessage, backportMessage);
    NSArray *backportRecipients = [backportMessage valueForKey:@"recipients"];
    revenant_check(backportRecipients.count == 1, "recipient count matches host", [NSString stringWithFormat:@"%lu", (unsigned long)backportRecipients.count]);
    revenant_expect_string("recipient display name", [backportRecipients.firstObject valueForKey:@"displayName"], @"Ada Lovelace");
    id backportSender = [backportMessage valueForKey:@"sender"];
    revenant_expect_string("sender display name", [backportSender valueForKey:@"displayName"], @"Ada Lovelace");
    revenant_check([hostMessage isEqual:[hostMessage copy]] == [backportMessage isEqual:[backportMessage copy]], "message equality matches host", [NSString stringWithFormat:@"%@ %@", hostMessage, backportMessage]);
    id decodedMessage = revenant_round_trip(backportMessage);
    revenant_check(decodedMessage && [backportMessage isEqual:decodedMessage], "message secure coding preserves equality", [NSString stringWithFormat:@"%@", decodedMessage]);
    return revenant_finish();
}
