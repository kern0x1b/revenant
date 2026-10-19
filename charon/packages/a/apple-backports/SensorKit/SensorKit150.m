#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 15.0, the properties that arrived then.
@implementation SRApplicationUsage (CharonSensorKit150)
@dynamic reportApplicationIdentifier, textInputSessions;
CHARON_VALUE_PROPERTY(NSString *, reportApplicationIdentifier)
CHARON_VALUE_PROPERTY(NSArray *, textInputSessions)
@end
@implementation SRApplicationUsage (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRKeyboardMetrics (CharonSensorKit150)
CHARON_VALUE_PROPERTY(NSArray *, inputModes)
-(NSInteger)totalPauses { NSNumber *boxed = [self charon_valueForKey:@"totalPauses"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalPauses:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalPauses"]; }
-(NSInteger)totalPathPauses { NSNumber *boxed = [self charon_valueForKey:@"totalPathPauses"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalPathPauses:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalPathPauses"]; }
-(double)typingSpeed { NSNumber *boxed = [self charon_valueForKey:@"typingSpeed"];
    return boxed ? (double)[boxed longLongValue] : (double)0; }
-(void)charon_setTypingSpeed:(double)value { [self charon_setValue:@(value) forKey:@"typingSpeed"]; }
-(double)pathTypingSpeed { NSNumber *boxed = [self charon_valueForKey:@"pathTypingSpeed"];
    return boxed ? (double)[boxed longLongValue] : (double)0; }
-(void)charon_setPathTypingSpeed:(double)value { [self charon_setValue:@(value) forKey:@"pathTypingSpeed"]; }
-(NSInteger)totalTypingEpisodes { NSNumber *boxed = [self charon_valueForKey:@"totalTypingEpisodes"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalTypingEpisodes:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalTypingEpisodes"]; }

// The two of SRKeyboardMetrics (SentimentCounts), at SRKeyboardMetrics.h:303 and :306. They arrive in
// 15.0, they live in a category of the SDK's own, and this is a category of ours for the same reason
// every other SRKeyboardMetrics accessor is written out by hand: a property the SDK's categories declare
// cannot be @dynamic here, and these are methods rather than properties, so the SDK's own declaration is
// what an application binds to and this body is what answers.
//
// The count is the SDK's own answer for a session with nothing in it: ZERO, not nil and not an error. The
// host's own SensorKit was asked over all ten SRKeyboardMetricsSentimentCategory cases for both methods
// and answered 0 for every one of the twenty - measured by the harness facts/SensorKit/SensorKit.md
// names. The value comes from the store under the selector and the category, which is this package's own
// key: the port invents no classification of a keyboard session, so a count is whatever an application
// archived under that key, and 0 when nothing was.
static NSString *CharonKeyboardSentimentKey(NSString *selector, NSInteger category)
{
    return [NSString stringWithFormat:@"%@%ld", selector, (long)category];
}

-(NSInteger)wordCountForSentimentCategory:(NSInteger)category
{
    return [[self charon_valueForKey:CharonKeyboardSentimentKey(@"wordCountForSentimentCategory:", category)]
            longLongValue];
}

-(NSInteger)emojiCountForSentimentCategory:(NSInteger)category
{
    return [[self charon_valueForKey:CharonKeyboardSentimentKey(@"emojiCountForSentimentCategory:", category)]
            longLongValue];
}
@end
@implementation SRTextInputSession
@dynamic duration, sessionType;
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_SCALAR_PROPERTY(SRTextInputSessionType, sessionType)
@end
@implementation SRTextInputSession (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

// The two string constants of iOS 15.0,
// declared at SRSensors.h:194 and :213,
// named from CharonSensorKitNames.h rather than written here: an object carries the API of
// one release alone, while the values are one list that the host comparison in
// tests/backports/host/sensorkit-names walks whole.

#define CHARON_SENSORKIT_NAMES_15_0
#import "CharonSensorKitNames.h"
