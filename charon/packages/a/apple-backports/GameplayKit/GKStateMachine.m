// GKStateMachine.m -- a state and the machine that runs it. GameplayKit.framework carries no code
// at all before iOS 9 (the SDK's own GK_BASE_AVAILABILITY is NS_CLASS_AVAILABLE(10_11, 9_0) and the
// 6.1.3 armv7 shared cache exports no GameplayKit class at all), so this is this port's own; the
// machine's own rules were measured on the host and are what the two classes below do:
//
//   -[GKState isValidNextState:] answers YES for every class unless a subclass says otherwise, and
//   the machine has no states of its own to consult before one has been entered: a fresh machine
//   -canEnterState: is YES for any class, measured.
//   -enterState: is that predicate and no more. When it passes, the state being left is told
//   -willExitWithNextState: (nil if the class has no state in the machine), the new state is
//   remembered and told -didEnterWithPreviousState: (nil if there was none), measured; and when
//   the class names no state in the machine it still answers YES and leaves the machine with no
//   current state, having told the state it was leaving that, measured.
//   -stateForClass: is an exact match on the class of the states the machine was built with, so a
//   subclass with no state of its own in the machine is not found, measured.
//   -updateWithDeltaTime: goes to the current state alone, and to none when there is none, measured.
//   -enterState: asks -canEnterState:, which asks the state it is leaving, so a state that refuses a
//   transition is asked about it and refuses the entry as well, measured.
//   -init and +new raise GKInitNotAllowedException rather than building a machine with no states,
//   with the host's own reason and the host's own spelling of it, measured.
//
// The two properties the SDK declares here are weak or readonly, and both are answered from an ivar
// this file keeps, with a getter of the class's own: -Wobjc-missing-property-synthesis does not fire
// on a property a class answers itself, and the pragma the archived version silenced it with is
// gone. What would fire is a member the port does NOT carry and does not say so with @dynamic, and
// there is none here.

#import "CharonGK.h"

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

// The three hooks below are what a state is for: a subclass fills them in, and until it does there
// is nothing for the machine to tell it. That is the whole of the base class.
- (void)didEnterWithPreviousState:(GKState *)previousState
{
}

- (void)updateWithDeltaTime:(NSTimeInterval)seconds
{
}

- (void)willExitWithNextState:(GKState *)nextState
{
}

// A state is a set of hooks a subclass fills in, so every one of them does nothing until it does,
// which is what the base class is for. What the base class has to answer is the question the machine
// asks before it moves: a plain state allows every transition, which is what the host's own does.
- (BOOL)isValidNextState:(Class)stateClass
{
    return YES;
}

- (GKStateMachine *)stateMachine
{
    return _machine;
}

- (void)charon_attachToStateMachine:(GKStateMachine *)machine
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
            [state charon_attachToStateMachine:self];
        }
    }
    return self;
}

// The machine has no state list of its own without -initWithStates:, and the host says so rather than
// building an empty one: -init and +new both raise GKInitNotAllowedException, with the host's own
// message and the host's own spelling of it (measured, tests/backports/host/gameplaykit-core/measure.m).
// That is why the archived version of this file silenced -Wobjc-designated-initializers instead of
// answering -init: the message below is the answer.
- (instancetype)init
{
    [NSException raise:@"GKInitNotAllowedException"
                format:@"initWithStates is the destignated initialize for GKStateMachine.  Use that instead"];
    // Unreachable, and written because clang wants a secondary initializer to delegate to a
    // designated one of its own class: the line above raises on every path, so no machine is ever
    // built here. The archived version of this file silenced that diagnostic with a pragma instead.
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
    [next charon_attachToStateMachine:self];
    [next didEnterWithPreviousState:previous];
    return YES;
}

- (void)updateWithDeltaTime:(NSTimeInterval)sec
{
    [_current updateWithDeltaTime:sec];
}

@end