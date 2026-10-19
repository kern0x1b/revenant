# The state machine

`GKState` and `GKStateMachine`. GameplayKit.framework carries no code at all before iOS 8, the SDK
declares both classes at 9.0 (`GK_BASE_AVAILABILITY` is `NS_CLASS_AVAILABLE(10_11, 9_0)` in the 16.4
build SDK and in the 26.2 one), and the 6.1.3 armv7 cache exports no GameplayKit class at all. Both
are therefore this port's own; they are measured against the host's own by
`tests/backports/host/gameplaykit-core/measure.m` and held to it by `differential.m`.

The machine's own rules, all measured:

- `-[GKState isValidNextState:]` answers YES for every class unless a subclass says otherwise, and
  the machine has no states of its own to consult before one has been entered: a fresh machine's
  `-canEnterState:` is YES for any class.
- `-enterState:` is that predicate and no more. When it passes, the state being left is told
  `-willExitWithNextState:` (nil if the class has no state in the machine), the new state is
  remembered and told `-didEnterWithPreviousState:` (nil if there was none), so the state leaving is
  told **before** the state arriving.
- `-stateForClass:` is an exact match on the class of the states the machine was built with, so a
  class it was never given is not found, and a subclass of a class it holds no state of is not found
  either. `-stateForClass:Nil` is nil.
- `-updateWithDeltaTime:` goes to the current state alone, and to none when there is none.
- Every state of a machine knows its machine, from the moment the machine is built. A state given to
  two machines knows the second: the machine claims its states as it is built, and the later claim
  wins.
- `-init` and `+new` **raise**, with `GKInitNotAllowedException` and the host's own reason, spelled as
  the host spells it: `initWithStates is the destignated initialize for GKStateMachine.  Use that
  instead`. The exception's userInfo is nil. The host does not build a machine with no states and the
  port does not either; the archived version of `GKStateMachine.m` answered `-init` with an empty
  state list and silenced the diagnostic that asked for one.

A state is a set of hooks a subclass fills in: `-didEnterWithPreviousState:`, `-updateWithDeltaTime:`
and `-willExitWithNextState:` do nothing until a subclass does, which is the whole of the base class.
That is not a silent fake: the base class is the thing a subclass overrides, and the machine never
depends on any of the three.

Both properties the SDK declares are weak or readonly and are answered from the ivar the class keeps,
with a getter of the class's own, so clang auto-synthesizes neither and no pragma says it should.

What is not here: nothing of the two classes.