#ifndef REVENANT_GK_SCRIPTED_SOURCE_H
#define REVENANT_GK_SCRIPTED_SOURCE_H

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

@interface RevenantGKScriptedSource : NSObject <GKRandom>
- (instancetype)initWithScript:(NSArray<NSString *> *)script;
@property (nonatomic, readonly) NSArray<NSString *> *trace;
@property (nonatomic, readonly) NSString *log;
- (NSArray *)arrayByShufflingObjectsInArray:(NSArray *)array;
@property (nonatomic, readonly) NSArray *shuffleAskedWith;
@end

@implementation RevenantGKScriptedSource {
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

- (NSString *)revenant_spend:(NSString *)kind
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
    return (NSInteger)[[self revenant_spend:@"int"] longLongValue];
}

- (NSUInteger)nextIntWithUpperBound:(NSUInteger)upperBound
{
    NSString *line = [self revenant_spend:[NSString stringWithFormat:@"bounded:%lu", (unsigned long)upperBound]];
    return line ? (NSUInteger)[line longLongValue] : 0;
}

- (float)nextUniform
{
    return (float)[[self revenant_spend:@"uniform"] doubleValue];
}

- (BOOL)nextBool
{
    return [[self revenant_spend:@"bool"] boolValue];
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
