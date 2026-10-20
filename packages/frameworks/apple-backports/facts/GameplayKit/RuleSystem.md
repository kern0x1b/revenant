# The rule system

`GKRule`, `GKRuleSystem` and `GKNSPredicateRule`. GameplayKit.framework carries no code at all before
iOS 8, the SDK declares all three at 9.0 (`GK_BASE_AVAILABILITY` is `NS_CLASS_AVAILABLE(10_11, 9_0)`),
and the 6.1.3 armv7 cache exports no GameplayKit class at all. All three are therefore this port's own,
measured against the host's own by `tests/backports/host/gameplaykit-core/measure.m` and held to it by
`differential.m`.

- **The agenda is kept, not built at evaluate time.** `-addRule:` puts a rule into the agenda at its
  place by salience, highest first and ties in the order they were added, so a system that has just
  been given rules already has an agenda of them; a rule added after an `-evaluate` goes into the agenda
  that evaluate left behind; `-reset` re-ranks the agenda over every rule. Measured: one add leaves
  agenda 1, a second add of a rule of salience 10 leaves the agenda `10 0`, and an add after a reset
  leaves it holding all four rules. The archived version filled the agenda only inside `-evaluate`, so
  a system that had just been given rules reported an empty agenda until it was evaluated.
- `-evaluate` walks the agenda once and fires every rule whose predicate is true **at the moment it is
  reached**, so an action that raises a grade can make a later rule's predicate true, and a rule fires
  at most once in a pass. Every rule that fires is in `-executed` in the order it fired, and the rules
  that did not are what the agenda is left holding. Measured with four rules of salience 0, 5, 5 and -3,
  of which the third's predicate is false and the fourth's reads a grade the first two have not yet
  raised: they fire in the order 5, 0, -3 and the rule of salience 5 that never fired stays in the
  agenda.
- A predicate is evaluated with the **system** as its object and the system's own `-state` dictionary as
  the source of its substitution variables, which is what `GKRuleSystem.h` says of the override and what
  the host does: with `state[@"mine"] = 1` the predicate `$mine == 1` answers YES, and `$absent == 1`
  raises `NSInvalidArgumentException` from `NSPredicate` for the missing binding. A block predicate is
  handed the system as its object and the state's contents as its bindings. A key path reads the
  system's key-value coding, not its `-state`.
- **A rule with no predicate never fires**: `-predicate` nil gives NO from
  `-evaluatePredicateWithSystem:`, and the action still runs. The archived version answered YES there,
  which made a predicate-less rule fire in every pass.
- A bare `GKRule`, which a subclass fills in, has no predicate of its own and answers YES from
  `-evaluatePredicateWithSystem:`; its `-performActionWithSystem:` does nothing. Both rule factories
  return a rule with a predicate, and on the host each is an instance of a **private** subclass,
  `_GKNSPredicateRule` for `+ruleWithPredicate:...` and `_GKBlockRule` for `+ruleWithBlockPredicate:`.
  The port answers the public class its own header names (`GKNSPredicateRule`); a private class would
  be a name no SDK header declares.
- A fact's grade is raised by `-assertFact:grade:` and lowered by `-retractFact:grade:`, and both clamp
  it to `[0, 1]`: asserting twice with a grade of 1 leaves 1, and retracting with a grade of 5 leaves 0.
  `-assertFact:` and `-retractFact:` are those with a grade of 1.
- `-gradeForFact:` of a fact never asserted is 0; `-minimumGradeForFacts:` of an empty list is 1 and
  `-maximumGradeForFacts:` of an empty list is 0, the neutral elements of the two.
- `-reset` clears the executed rules, the facts and the grades, **leaves the agenda holding every rule
  by salience** (`5 5 0 -3` in the measurement above), and keeps the rules. `-removeAllRules` takes the
  rules as well.
- `-state` is an empty mutable dictionary the caller may use, and stays empty unless the caller puts
  something in it: the grades live in the system itself, not in `-state`.
- A rule's salience is 0 until it is set. The rule system raises nothing of its own: the only
  exceptions a caller can see from it are the ones `NSPredicate` raises for a missing substitution
  variable and for a key the system is not key-value coding compliant for.

Every property the SDK declares here is answered from the ivar the class keeps, with a getter of the
class's own, so clang auto-synthesizes none and no pragma says it should.

What is not here: nothing of the three classes.