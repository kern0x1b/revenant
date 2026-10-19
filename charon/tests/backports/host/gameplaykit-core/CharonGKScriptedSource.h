// CharonGKScriptedSource.h -- a GKRandom that answers a written script instead of a generator, and
// writes down what it was asked.
//
// The port's own random sources are NOT the host's: facts/GameplayKit/GKRandomSource.md records that
// the three generators are unidentified and that the sequences differ, so no check can compare a
// number that came out of one source against the same number out of the other. What CAN be compared
// is what the families ON TOP of a source do with it, and that is a question about which protocol
// methods are called, in which order, and how their answers are combined -- none of which needs a
// generator.
//
// So a script is a list of strings, one per call the source will receive, each naming the call and the
// answer: "int=7", "bounded:6=2", "uniform=0.5", "bool=1". A call whose kind does not match the next
// line of the script records "MISMATCH <asked> <expected>" instead, and a script that runs out records
// "starved". The trace is the script as it was spent, so the same script prints the same trace on the
// host and on the port, and any difference in which method a distribution reached for shows up as a
// difference in the text.
//
// This is the oracle for the distributions and for the shuffle; every family here is measured with it
// in tests/backports/host/gameplaykit-core/{measure,differential}.m. It is a header because both of
// those are separate binaries and the run must not link them together.
#ifndef CHARON_GK_SCRIPTED_SOURCE_H
#define CHARON_GK_SCRIPTED_SOURCE_H

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

@interface CharonGKScriptedSource : NSObject <GKRandom>
// The answers, in the order they will be given: "int=7", "bounded:6=2", "uniform=0.5", "bool=1".
- (instancetype)initWithScript:(NSArray<NSString *> *)script;
// What the source was asked, one entry per call, each the script line it answered or a note.
@property (nonatomic, readonly) NSArray<NSString *> *trace;
// The script joined by spaces, which is what a report quotes.
@property (nonatomic, readonly) NSString *log;
// The shuffle the host's own -[NSArray shuffledArrayWithRandomSource:] reaches for: it hands the array
// to the source and the source does the shuffling, so the source needs this to be asked at all. The
// answer is the array itself, unchanged, which is what a recorder has to answer to be recognisable.
- (NSArray *)arrayByShufflingObjectsInArray:(NSArray *)array;
// Set when the shuffle above was reached for, with the array it was given.
@property (nonatomic, readonly) NSArray *shuffleAskedWith;
@end

@implementation CharonGKScriptedSource {
    NSArray<NSString *> *_script;
    NSMutableArray<NSString *> *_trace;
    NSArray *_shuffleAskedWith;
    NSUInteger _next;
}

- (instancetype)initWithScript:(NSArray<NSString *> *)script
{
    self = [super init];
    if (self) {
        _script = [script copy];
        _trace = [NSMutableArray arrayWithCapacity:[script count]];
    }
    return self;
}

- (NSArray<NSString *> *)trace
{
    return _trace;
}

- (NSString *)log
{
    return [_trace componentsJoinedByString:@" "];
}

// The one place a line of the script is matched against the call that arrived. A line that does not
// match is spent and noted, so a family that reached for a different method shows the mismatch in the
// trace instead of quietly taking the answer meant for another call.
- (NSString *)charon_spend:(NSString *)kind
{
    if (_next >= [_script count]) {
        [_trace addObject:[NSString stringWithFormat:@"starved(%@)", kind]];
        return nil;
    }
    NSString *line = _script[_next++];
    if (![line hasPrefix:[kind stringByAppendingString:@"="]]) {
        [_trace addObject:[NSString stringWithFormat:@"MISMATCH(asked %@, expected %@)", kind,
                            [line componentsSeparatedByString:@"="].firstObject]];
        return nil;
    }
    [_trace addObject:line];
    return [line substringFromIndex:[kind length] + 1];
}

- (NSInteger)nextInt
{
    return (NSInteger)[[self charon_spend:@"int"] longLongValue];
}

- (NSUInteger)nextIntWithUpperBound:(NSUInteger)upperBound
{
    NSString *line = [self charon_spend:[NSString stringWithFormat:@"bounded:%lu", (unsigned long)upperBound]];
    return line ? (NSUInteger)[line longLongValue] : 0;
}

- (float)nextUniform
{
    return (float)[[self charon_spend:@"uniform"] doubleValue];
}

- (BOOL)nextBool
{
    return [[self charon_spend:@"bool"] boolValue];
}

- (NSArray *)arrayByShufflingObjectsInArray:(NSArray *)array
{
    _shuffleAskedWith = array;
    [_trace addObject:[NSString stringWithFormat:@"shuffle(%lu)", (unsigned long)[array count]]];
    return array;
}

- (NSArray *)shuffleAskedWith
{
    return _shuffleAskedWith;
}

@end

#endif