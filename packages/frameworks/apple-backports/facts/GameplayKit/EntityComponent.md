# The entity-component system

`GKEntity`, `GKComponent` and `GKComponentSystem`. GameplayKit.framework carries no code at all before
iOS 8, the SDK declares all three at 9.0 (`GK_BASE_AVAILABILITY` is `NS_CLASS_AVAILABLE(10_11, 9_0)`),
and the 6.1.3 armv7 cache exports no GameplayKit class at all. All three are therefore this port's
own, measured against the host's own by `tests/backports/host/gameplaykit-core/measure.m` and held to
it by `differential.m`.

- An entity holds **one component per component class**, keyed by that class: adding a second
  component of a class it already has replaces the first, `-componentForClass:` is nil for a class it
  does not have and for `Nil`, and `-components` is in no defined order (on the host, adding C1 then C2
  to one entity gives C2, C1, and adding C2 then C1 to another gives C2, C1 as well, which is a
  dictionary's order and not an insertion order).
  **This port answers `-components` in the order the components were added**, which is the order an
  application can rely on and costs one array. The header promises no order either way, so neither
  answer is a different behaviour; this one is the reproducible one. The archived version of
  `GKComponentSystem.m` already did this and said so here; it is kept.
- `-addComponent:` sets the component's entity and tells it `-didAddToEntity`, `-removeComponentForClass:`
  tells it `-willRemoveFromEntity` and clears its entity, and `-updateWithDeltaTime:` goes to every
  component. Adding a component that replaces another tells the new one `-didAddToEntity` and the
  replaced one nothing. Removing a class the entity has no component of changes nothing.
- A component's three hooks, `-updateWithDeltaTime:`, `-didAddToEntity` and `-willRemoveFromEntity`, do
  nothing until a subclass does, which is the whole of the base class.
- A component system holds the components of one class in the order they were added, enumerates them,
  forwards `-updateWithDeltaTime:` to each, and `-addComponentWithEntity:` takes only the entity's
  component of the system's own class, so an entity holding a component of another class adds nothing.
  `-classForGenericArgumentAtIndex:` answers the system's component class for every index, 0 and 9
  included.
- `-addComponent:` **raises** `NSInvalidArgumentException` with the host's own message, `component
  class is not supported by this system`, for a component of another class and for `nil` alike. The
  archived version dropped such a component silently, which is the silent fake the tree forbids: an
  application that added a component of the wrong class to its system saw no error and no component.
- An entity is an `NSCopying` and an `NSSecureCoding`, and so is a component. A copy is an entity of
  its own with a copy of each component. An archive writes down which class each component is and,
  under that class's own key, the bytes the component's `-encodeWithCoder:` produced, so a component
  that carries state of its own is carried with it and one that does not comes back as the class it
  was. That is a component's own coder, not a nested archive of the entity's.
  The nested archive is written and read with `+[NSKeyedArchiver archivedDataWithRootObject:]` and
  `+[NSKeyedUnarchiver unarchiveObjectWithData:]`, not with the `requiringSecureCoding:error:` pair that
  needs iOS 11: an object holds the API of exactly one release and this one's is 9.0.

Every property the SDK declares here is weak or readonly and is answered from the ivar the class keeps,
with a getter of the class's own, so clang auto-synthesizes none and no pragma says it should.

What is not here: nothing of the three classes.