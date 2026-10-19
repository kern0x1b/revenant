#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRApplicationUsage (RevenantSensorKit150)
@dynamic reportApplicationIdentifier, textInputSessions;
REVENANT_VALUE_PROPERTY(NSString *, reportApplicationIdentifier)
REVENANT_VALUE_PROPERTY(NSArray *, textInputSessions)
@end
@implementation SRApplicationUsage (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRKeyboardMetrics (RevenantSensorKit150)
REVENANT_VALUE_PROPERTY(NSArray *, inputModes)
-(NSInteger)totalPauses { NSNumber *boxed = [self revenant_valueForKey:@"totalPauses"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalPauses:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalPauses"]; }
-(NSInteger)totalPathPauses { NSNumber *boxed = [self revenant_valueForKey:@"totalPathPauses"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalPathPauses:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalPathPauses"]; }
-(double)typingSpeed { NSNumber *boxed = [self revenant_valueForKey:@"typingSpeed"];
    return boxed ? (double)[boxed longLongValue] : (double)0; }
-(void)revenant_setTypingSpeed:(double)value { [self revenant_setValue:@(value) forKey:@"typingSpeed"]; }
-(double)pathTypingSpeed { NSNumber *boxed = [self revenant_valueForKey:@"pathTypingSpeed"];
    return boxed ? (double)[boxed longLongValue] : (double)0; }
-(void)revenant_setPathTypingSpeed:(double)value { [self revenant_setValue:@(value) forKey:@"pathTypingSpeed"]; }
-(NSInteger)totalTypingEpisodes { NSNumber *boxed = [self revenant_valueForKey:@"totalTypingEpisodes"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalTypingEpisodes:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalTypingEpisodes"]; }

static NSString *RevenantKeyboardSentimentKey(NSString *selector, NSInteger category)
{
    return [NSString stringWithFormat:@"%@%ld", selector, (long)category];
}

-(NSInteger)wordCountForSentimentCategory:(NSInteger)category
{
    return [[self revenant_valueForKey:RevenantKeyboardSentimentKey(@"wordCountForSentimentCategory:", category)]
            longLongValue];
}

-(NSInteger)emojiCountForSentimentCategory:(NSInteger)category
{
    return [[self revenant_valueForKey:RevenantKeyboardSentimentKey(@"emojiCountForSentimentCategory:", category)]
            longLongValue];
}
@end
@implementation SRTextInputSession
@dynamic duration, sessionType;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
REVENANT_SCALAR_PROPERTY(SRTextInputSessionType, sessionType)
@end
@implementation SRTextInputSession (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

#define REVENANT_SENSORKIT_NAMES_15_0
#import "RevenantSensorKitNames.h"
