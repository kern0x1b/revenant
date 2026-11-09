#import <UIKit/UIKit.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#include <unistd.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;
static NSString *const REVENANT_RESULT = @"/var/revenant/intents-probe.txt";

static void revenant_line(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void revenant_line(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [REVENANT_LOG appendFormat:@"%@\n", [[NSString alloc] initWithFormat:format arguments:arguments]];
    va_end(arguments);
    [REVENANT_LOG writeToFile:REVENANT_RESULT atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    revenant_line(@"%@ %@", ok ? @"PASS" : @"FAIL", name);
}

static id revenant_round_trip(id value)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver setRequiresSecureCoding:YES];
    [archiver encodeObject:value forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    [unarchiver setRequiresSecureCoding:YES];
    id decoded = [unarchiver decodeObjectOfClass:[value class] forKey:@"root"];
    [unarchiver finishDecoding];
    return decoded;
}

static INPerson *revenant_person(NSString *name)
{
    INPersonHandle *handle = [[INPersonHandle alloc] initWithValue:name type:INPersonHandleTypeUnknown];
    return [[INPerson alloc] initWithPersonHandle:handle nameComponents:nil displayName:name image:nil contactIdentifier:nil customIdentifier:name];
}

static NSInteger revenant_status(id result)
{
    return [[result valueForKey:@"resolutionStatus"] integerValue];
}

static void revenant_response_checks(void)
{
    INSendMessageIntentResponse *sent = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeSuccess userActivity:nil];
    revenant_check(sent.code == INSendMessageIntentResponseCodeSuccess && sent.userActivity == nil, @"send message response keeps its code");
    revenant_check([[sent description] rangeOfString:@"code=success"].location != NSNotFound, @"send message response names its code");
    INSendMessageIntentResponse *sentRestored = revenant_round_trip(sent);
    revenant_check([sentRestored isKindOfClass:[INSendMessageIntentResponse class]] && sentRestored.code == INSendMessageIntentResponseCodeSuccess, @"send message response survives secure coding");
    INSendMessageIntentResponse *sentCopy = [sent copy];
    revenant_check(sentCopy != nil && sentCopy.code == INSendMessageIntentResponseCodeSuccess, @"send message response copies");
    INSendMessageIntentResponse *failure = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeFailureRequiringAppLaunch userActivity:nil];
    revenant_check(failure.code == INSendMessageIntentResponseCodeFailureRequiringAppLaunch, @"send message response keeps a failure code");

    INSearchForMessagesIntentResponse *search = [[INSearchForMessagesIntentResponse alloc] initWithCode:INSearchForMessagesIntentResponseCodeFailureMessageServiceNotAvailable userActivity:nil];
    revenant_check(search.code == INSearchForMessagesIntentResponseCodeFailureMessageServiceNotAvailable && search.messages == nil, @"search messages response keeps its code");
    search.messages = @[];
    revenant_check([search.messages isEqual:@[]], @"search messages response keeps its messages");
    revenant_check([revenant_round_trip(search) code] == INSearchForMessagesIntentResponseCodeFailureMessageServiceNotAvailable, @"search messages response survives secure coding");

    INSetMessageAttributeIntentResponse *attribute = [[INSetMessageAttributeIntentResponse alloc] initWithCode:INSetMessageAttributeIntentResponseCodeFailureMessageNotFound userActivity:nil];
    revenant_check(attribute.code == INSetMessageAttributeIntentResponseCodeFailureMessageNotFound, @"set message attribute response keeps its code");
    revenant_check([revenant_round_trip(attribute) code] == INSetMessageAttributeIntentResponseCodeFailureMessageNotFound, @"set message attribute response survives secure coding");

    INSearchCallHistoryIntentResponse *history = [[INSearchCallHistoryIntentResponse alloc] initWithCode:INSearchCallHistoryIntentResponseCodeSuccess userActivity:nil];
    INCallRecord *record = [[INCallRecord alloc] initWithIdentifier:@"call" dateCreated:[NSDate dateWithTimeIntervalSince1970:100] callRecordType:INCallRecordTypeMissed callCapability:INCallCapabilityAudioCall callDuration:@5 unseen:@YES];
    history.callRecords = @[record];
    revenant_check(history.code == INSearchCallHistoryIntentResponseCodeSuccess && [history.callRecords count] == 1, @"search call history response keeps its records");
    INSearchCallHistoryIntentResponse *historyRestored = revenant_round_trip(history);
    revenant_check([historyRestored.callRecords.firstObject isEqual:record], @"search call history response survives secure coding with its records");

    INStartCallIntentResponse *start = [[INStartCallIntentResponse alloc] initWithCode:INStartCallIntentResponseCodeFailureAppConfigurationRequired userActivity:nil];
    revenant_check(start.code == INStartCallIntentResponseCodeFailureAppConfigurationRequired, @"start call response keeps its code");
}

static void revenant_search_messages_checks(void)
{
    INPerson *ada = revenant_person(@"ada");
    INPerson *grace = revenant_person(@"grace");
    INSearchForMessagesIntent *intent = [[INSearchForMessagesIntent alloc] initWithRecipients:@[ada] senders:@[grace] searchTerms:@[@"lunch"] attributes:INMessageAttributeOptionUnread dateTimeRange:nil identifiers:@[@"1", @"2"] notificationIdentifiers:@[@"n"] speakableGroupNames:nil conversationIdentifiers:@[@"c"]];
    revenant_check([intent.recipients isEqual:@[ada]] && [intent.senders isEqual:@[grace]], @"search messages intent keeps recipients and senders");
    revenant_check([intent.searchTerms isEqual:@[@"lunch"]] && intent.attributes == INMessageAttributeOptionUnread, @"search messages intent keeps terms and attributes");
    revenant_check([intent.identifiers isEqual:(@[@"1", @"2"])] && [intent.notificationIdentifiers isEqual:@[@"n"]] && [intent.conversationIdentifiers isEqual:@[@"c"]], @"search messages intent keeps identifiers");
    revenant_check(intent.recipientsOperator == INConditionalOperatorAll && intent.sendersOperator == INConditionalOperatorAll, @"search messages intent defaults its operators to all");
    INSearchForMessagesIntent *restored = revenant_round_trip(intent);
    revenant_check([restored isKindOfClass:[INSearchForMessagesIntent class]] && [restored.recipients isEqual:@[ada]] && restored.attributes == INMessageAttributeOptionUnread && [restored.identifiers isEqual:(@[@"1", @"2"])], @"search messages intent survives secure coding");
    INSearchForMessagesIntent *copy = [intent copy];
    revenant_check([copy.searchTerms isEqual:intent.searchTerms] && copy.attributes == intent.attributes, @"search messages intent copies");
    revenant_check(![[intent description] isEqualToString:@""], @"search messages intent describes itself");
    INSearchForMessagesIntent *plain = [[INSearchForMessagesIntent alloc] init];
    revenant_check(plain.recipients == nil && plain.attributes == 0, @"search messages intent starts empty");

    INSetMessageAttributeIntent *set = [[INSetMessageAttributeIntent alloc] initWithIdentifiers:@[@"1"] attribute:INMessageAttributeFlagged];
    revenant_check([set.identifiers isEqual:@[@"1"]] && set.attribute == INMessageAttributeFlagged, @"set message attribute intent keeps its values");
    INSetMessageAttributeIntent *setRestored = revenant_round_trip(set);
    revenant_check([setRestored.identifiers isEqual:@[@"1"]] && setRestored.attribute == INMessageAttributeFlagged, @"set message attribute intent survives secure coding");
    INSetMessageAttributeIntent *setCopy = [set copy];
    revenant_check(setCopy.attribute == INMessageAttributeFlagged && [setCopy.identifiers isEqual:@[@"1"]], @"set message attribute intent copies");
}

static void revenant_calls_checks(void)
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000];
    INPerson *ada = revenant_person(@"ada");
    INCallRecord *record = [[INCallRecord alloc] initWithIdentifier:@"call" dateCreated:date callRecordType:INCallRecordTypeReceived callCapability:INCallCapabilityVideoCall callDuration:@42.5 unseen:@NO numberOfCalls:@3];
    revenant_check([record.identifier isEqualToString:@"call"] && [record.dateCreated isEqual:date] && record.callRecordType == INCallRecordTypeReceived && record.callCapability == INCallCapabilityVideoCall, @"call record keeps its values");
    revenant_check([record.callDuration isEqual:@42.5] && [record.unseen isEqual:@NO] && [record.numberOfCalls isEqual:@3], @"call record keeps its numbers");
    INCallRecord *caller = [[INCallRecord alloc] initWithIdentifier:@"caller" dateCreated:date caller:ada callRecordType:INCallRecordTypeOutgoing callCapability:INCallCapabilityAudioCall callDuration:nil unseen:nil];
    revenant_check([caller.caller isEqual:ada] && [caller.participants isEqual:@[ada]], @"call record keeps its caller as the first participant");
    INCallRecord *restored = revenant_round_trip(record);
    revenant_check([restored isEqual:record] && [restored hash] == [record hash], @"call record survives secure coding");
    INCallRecord *copy = [record copy];
    revenant_check([copy isEqual:record] && ![copy isEqual:caller], @"call record copies and compares");

    INSearchCallHistoryIntent *intent = [[INSearchCallHistoryIntent alloc] initWithDateCreated:nil recipient:ada callCapabilities:INCallCapabilityOptionVideoCall callTypes:INCallRecordTypeOptionMissed | INCallRecordTypeOptionReceived unseen:@YES];
    revenant_check(intent.dateCreated == nil && [intent.recipient isEqual:ada] && intent.callCapabilities == INCallCapabilityOptionVideoCall, @"search call history intent keeps its values");
    revenant_check(intent.callTypes == (INCallRecordTypeOptionMissed | INCallRecordTypeOptionReceived) && [intent.unseen isEqual:@YES], @"search call history intent keeps its call types");
    INSearchCallHistoryIntent *legacy = [[INSearchCallHistoryIntent alloc] initWithCallType:INCallRecordTypeMissed dateCreated:nil recipient:nil callCapabilities:INCallCapabilityOptionAudioCall];
    revenant_check(legacy.callTypes == INCallRecordTypeOptionMissed && legacy.callType == INCallRecordTypeMissed, @"the call type initializer maps to the call type options");
    INSearchCallHistoryIntent *intentRestored = revenant_round_trip(intent);
    revenant_check(intentRestored.callTypes == intent.callTypes && [intentRestored.recipient isEqual:ada] && [intentRestored.unseen isEqual:@YES], @"search call history intent survives secure coding");
    INSearchCallHistoryIntent *intentCopy = [intent copy];
    revenant_check(intentCopy.callTypes == intent.callTypes && [intentCopy.unseen isEqual:@YES], @"search call history intent copies");
    revenant_check([intentCopy isEqual:intent] && [intentCopy hash] == [intent hash] && ![intentCopy isEqual:legacy], @"search call history intents compare by value");
}

static void revenant_image_checks(void)
{
    INSendMessageIntent *intent = [[INSendMessageIntent alloc] initWithRecipients:nil outgoingMessageType:INOutgoingMessageTypeOutgoingMessageText content:@"hi" speakableGroupName:nil conversationIdentifier:@"c" serviceName:nil sender:nil attachments:nil];
    INImage *image = [INImage imageWithImageData:[@"image" dataUsingEncoding:NSUTF8StringEncoding]];
    [intent setImage:image forParameterNamed:@"content"];
    revenant_check([intent imageForParameterNamed:@"content"] == image, @"an intent keeps the image of a parameter");
    INSendMessageIntent *copy = [intent copy];
    [copy setImage:nil forParameterNamed:@"content"];
    revenant_check([copy imageForParameterNamed:@"content"] == nil && [intent imageForParameterNamed:@"content"] == image, @"the copy of an intent has its own image table");
}

static void revenant_results_checks(void)
{
    INPerson *ada = revenant_person(@"ada");
    INPerson *grace = revenant_person(@"grace");
    INPersonResolutionResult *success = [INPersonResolutionResult successWithResolvedPerson:ada];
    revenant_check(revenant_status(success) == 3 && [[success valueForKey:@"resolvedValue"] isEqual:ada], @"person success resolves the person");
    INPersonResolutionResult *disambiguation = [INPersonResolutionResult disambiguationWithPeopleToDisambiguate:@[ada, grace]];
    revenant_check(revenant_status(disambiguation) == 4 && [[disambiguation valueForKey:@"valuesToDisambiguate"] count] == 2, @"person disambiguation keeps the people");
    INPersonResolutionResult *confirmation = [INPersonResolutionResult confirmationRequiredWithPersonToConfirm:ada];
    revenant_check(revenant_status(confirmation) == 5 && [[confirmation valueForKey:@"valueToConfirm"] isEqual:ada], @"person confirmation keeps the person");
    revenant_check(revenant_status([INPersonResolutionResult needsValue]) == 0 && revenant_status([INPersonResolutionResult notRequired]) == 1 && revenant_status([INPersonResolutionResult unsupported]) == 2, @"person needs value, not required and unsupported");

    INSendMessageRecipientResolutionResult *noValid = [INSendMessageRecipientResolutionResult unsupportedForReason:INSendMessageRecipientUnsupportedReasonNoValidHandle];
    revenant_check(revenant_status(noValid) == 2 && [noValid isKindOfClass:[INPersonResolutionResult class]], @"recipient unsupported keeps the unsupported status");
    revenant_check([[noValid description] rangeOfString:@"reason=noValidHandle"].location != NSNotFound, @"recipient unsupported names its reason");
    INSendMessageRecipientResolutionResult *adopted = [[INSendMessageRecipientResolutionResult alloc] initWithPersonResolutionResult:success];
    revenant_check(revenant_status(adopted) == 3 && [[adopted valueForKey:@"resolvedValue"] isEqual:ada], @"a recipient result adopts a person result");

    INStartCallContactResolutionResult *contact = [INStartCallContactResolutionResult unsupportedForReason:INStartCallContactUnsupportedReasonNoContactFound];
    revenant_check(revenant_status(contact) == 2, @"start call contact unsupported keeps the unsupported status");
    INStartCallContactResolutionResult *contactAdopted = [[INStartCallContactResolutionResult alloc] initWithPersonResolutionResult:disambiguation];
    revenant_check(revenant_status(contactAdopted) == 4, @"a start call contact result adopts a person result");

    INStringResolutionResult *string = [INStringResolutionResult successWithResolvedString:@"term"];
    revenant_check(revenant_status(string) == 3 && [[string valueForKey:@"resolvedValue"] isEqual:@"term"], @"string success keeps the string");
    INStringResolutionResult *strings = [INStringResolutionResult disambiguationWithStringsToDisambiguate:@[@"a", @"b"]];
    revenant_check(revenant_status(strings) == 4 && [[strings valueForKey:@"valuesToDisambiguate"] count] == 2, @"string disambiguation keeps the strings");
    revenant_check(revenant_status([INStringResolutionResult confirmationRequiredWithStringToConfirm:@"term"]) == 5, @"string confirmation is a confirmation");

    INMessageAttributeResolutionResult *attribute = [INMessageAttributeResolutionResult successWithResolvedMessageAttribute:INMessageAttributeRead];
    revenant_check(revenant_status(attribute) == 3 && [[[attribute valueForKey:@"resolvedValue"] description] isEqualToString:[@(INMessageAttributeRead) description]], @"message attribute success keeps the attribute");
    INMessageAttributeOptionsResolutionResult *options = [INMessageAttributeOptionsResolutionResult successWithResolvedMessageAttributeOptions:INMessageAttributeOptionRead | INMessageAttributeOptionFlagged];
    revenant_check(revenant_status(options) == 3, @"message attribute options success resolves");
    revenant_check(revenant_status([INMessageAttributeOptionsResolutionResult confirmationRequiredWithMessageAttributeOptionsToConfirm:INMessageAttributeOptionUnread]) == 5, @"message attribute options confirmation is a confirmation");

    INCallDestinationTypeResolutionResult *destination = [INCallDestinationTypeResolutionResult successWithResolvedCallDestinationType:INCallDestinationTypeNormal];
    revenant_check(revenant_status(destination) == 3 && [[destination valueForKey:@"resolvedValue"] integerValue] == INCallDestinationTypeNormal, @"call destination type success keeps the type");
    revenant_check(revenant_status([INCallDestinationTypeResolutionResult confirmationRequiredWithCallDestinationTypeToConfirm:INCallDestinationTypeEmergency]) == 5, @"call destination type confirmation is a confirmation");
}

@interface RevenantIntentsDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantIntentsDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(revenantRun) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)revenantRun
{
    REVENANT_LOG = [NSMutableString string];
    revenant_line(@"INFO %@ iOS %@", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]);
    revenant_response_checks();
    revenant_search_messages_checks();
    revenant_calls_checks();
    revenant_image_checks();
    revenant_results_checks();
    revenant_line(@"REVENANT-DONE failures %lu", (unsigned long)REVENANT_FAILURES);
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantIntentsDelegate class]));
    }
}
