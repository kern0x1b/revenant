#import "RevenantGK.h"

@implementation GKState {
    __weak GKStateMachine *_machine;
}

+ (instancetype)state
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [super init];
}

- (void)didEnterWithPreviousState:(GKState *)previousState
{
}

- (void)updateWithDeltaTime:(NSTimeInterval)seconds
{
}

- (void)willExitWithNextState:(GKState *)nextState
{
}

- (BOOL)isValidNextState:(Class)stateClass
{
    return YES;
}

- (GKStateMachine *)stateMachine
{
    return _machine;
}

- (void)revenant_attachToStateMachine:(GKStateMachine *)machine
{
    _machine = machine;
}

@end

@implementation GKStateMachine {
    NSArray<GKState *> *_states;
    GKState *_current;
}

+ (instancetype)stateMachineWithStates:(NSArray<GKState *> *)states
{
    return [[self alloc] initWithStates:states];
}

- (instancetype)initWithStates:(NSArray<GKState *> *)states
{
    self = [super init];
    if (self) {
        _states = [states copy];
        for (GKState *state in _states) {
            [state revenant_attachToStateMachine:self];
        }
    }
    return self;
}

- (instancetype)init
{
    [NSException raise:@"GKInitNotAllowedException"
                format:@"initWithStates is the destignated initialize for GKStateMachine.  Use that instead"];
    return [self initWithStates:@[]];
}

- (GKState *)currentState
{
    return _current;
}

- (GKState *)stateForClass:(Class)stateClass
{
    if (!stateClass) {
        return nil;
    }
    for (GKState *state in _states) {
        if ([state class] == stateClass) {
            return state;
        }
    }
    return nil;
}

- (BOOL)canEnterState:(Class)stateClass
{
    if (!_current) {
        return YES;
    }
    return [_current isValidNextState:stateClass];
}

- (BOOL)enterState:(Class)stateClass
{
    if (![self canEnterState:stateClass]) {
        return NO;
    }
    GKState *next = [self stateForClass:stateClass];
    GKState *previous = _current;
    [previous willExitWithNextState:next];
    _current = next;
    [next revenant_attachToStateMachine:self];
    [next didEnterWithPreviousState:previous];
    return YES;
}

- (void)updateWithDeltaTime:(NSTimeInterval)sec
{
    [_current updateWithDeltaTime:sec];
}

@end
