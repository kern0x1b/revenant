# UIKit Dynamics, iOS 7.0: UIDynamicAnimator and the 7.0 behaviours

Introduced in iOS 7.0: `UIDynamicAnimator`, `UIDynamicBehavior` and the six behaviours (item, gravity, push, snap, attachment,
collision), the protocols `UIDynamicItem`, `UIDynamicAnimatorDelegate`, `UICollisionBehaviorDelegate`; with the 9.0 members of
these classes (`frictionTorque`, `attachmentRange` and five factories of the attachment, `charge` and `anchored`, `snapPoint`,
`UIFloatRange`). The 9.0 classes are in `UIFieldBehavior.md`. Code: `UIKit/UIDynamicAnimator.mm` (world, bodies, contact filter
and listener), one `.mm` per behaviour, `UIKit/CharonDynamics.h`, over unmodified Box2D 2.2.1 (`packages/b/box2d`), the engine
iOS 7.0's private PhysicsKit is a fork of.

Marks: **measured (host)** = the host's UIKitCore and PhysicsKit through Mac Catalyst (arm64e, macOS 27.0), by the band's oracle
probes (named by file, not in the tree), and held against the port by `tests/backports/host/dynamics` (§12); **read (7.0)** =
the iOS 7.0 arm64 dyld cache (`~/.charon/dyld/7.0`) disassembled with ivar names resolved (its PhysicsKit carries
`PhysicsKit-4.6/PhysicsKit/Box2D`, 2.2.1's joint layout, no motor joint); **predicted (7.0)** = a float program of the 7.0
integrator (`w_sim7.c`), not a device. Units: 100 pt per metre (`_ptmRatio`, measured); positions cross as
`(float)(0.01f * (double)pt)` and back as `(double)(100.0f * b2)`, in float (measured `b_wb.m`); angles unscaled, clockwise on
screen. Section `§N` is the band's 7.0 specification's §N, `MN` its second measurement round's §N.

## §0. Target and the two time bases

**Rule: the 7.0 classes implement iOS 7.0's behaviour as far as unmodified Box2D 2.2.1 expresses it.** The host oracle differs
from 7.0 in two integrator details only; the UIKit side has the same structure on both.

| item | iOS 7.0 (shipped) | host oracle (what the Catalyst probes measure) |
|---|---|---|
| sub-step | h = (float)(speed * 0.004) s, fixed | h = 0.00833333377f s ((float)1/120), fixed |
| loop | `total = acc + dt; acc = fmod(total, 0.004); if (total > 0.004) do { Step(h, 8, 3); total -= 0.004; } while (total > 0.004);` | `acc += dt * speed; while (acc >= (double)h) { Step(h, 8, 3); acc -= (double)h; }` |
| sub-steps per 1/60 frame | 4 (every 6th frame 5) | 1 on the first frame, then 2 |
| damping | 2.2.1 clamp `v *= b2Clamp(1 - h*c, 0, 1)` = upstream b2Island | `v *= 1/(1 + h*c)` (the Box2D 2.3 form) |
| shapes | box 1 pt inside the item on every side, `m_radius` 0.001 m on boxes, edges and chains (§2.3, §7.4) | full-size box, radius 0 |

So a trajectory cannot be compared bit-exactly with the host. The sources are built with `CHARON_HOST_DIFFERENTIAL` for the
host test, which switches the sub-step and the shapes to the host's column (`charon_host_integrator` in
`UIDynamicAnimator.mm`); the damping stays 2.2.1's (unmodified Box2D), so trajectory rows either set the resistance to 0 or
carry a tolerance for it (§12). Everything that is not an integrator detail is the same on both.

## §1. World and time

### §1.1 The b2World

Read (7.0, `-[PKPhysicsWorld init]`): sleeping and continuous physics on, warm starting on, sub-stepping off (7.0's
`b2World::Step` is the stock 2.2.1 one), a contact listener, and **`SetAutoClearForces(false)`**: `ClearForces()` runs once
after all sub-steps of one step, so a force applied before the step acts in every sub-step. Made by the first registration.

**Gravity is the world's, not a per-item force**: measured (`w_fall2.m`), a gravity behaviour of magnitude 1 sets the world to
(0, 10) m/s^2 and the fall is reproduced bit-exactly by world gravity alone; a trace of the step shows no force call. With
2.2.1: `SetGravity(10 * g)` and `SetGravityScale(inGravityBehavior ? 1 : 0)` (§3).

### §1.2 The step: fixed sub-steps with an accumulator

`_animatorStep:dt` passes dt unchanged to `stepWithTime:dt velocityIterations:8 positionIterations:3`. Read (7.0):

```
if (bodies.count == 0) return NO;
if ((float)dt is negative, zero or below 2^-63) return YES;
total = acc + dt; acc = fmod(total, 0.004);
if (total > 0.004) { h = (float)((double)speed * 0.004); do { Step(h, 8, 3); total += -0.004; } while (total > 0.004); }
flush the contact records (§7.5); ClearForces(); run the world's post-step blocks;
for (body in bodies, add order) { write back (§2.8); if (dynamic) allResting &= !IsAwake(); }
return !allResting;
```

At dt = 1/60: 4 sub-steps, every 6th call 5. Measured (host, constants read with lldb): the host's loop of §0, step
0.008333333767950535f.

### §1.3 The first-step anomaly (host) and the 7.0 prediction

Measured (`w_fall2.m`), 100x100 item at (150, 50), gravity only, steps of 1/60: y = 50.0693855, 50.4160881, 51.0396423,
51.9395943, 53.1154747 with resistance 0.1 (vy 8.32639503 ... 74.6884308 pt/s); 50.0694466, 50.4166718, 51.0416679, 51.9444466,
53.1250076 with resistance 0. The host's first call does one sub-step of 1/120, every later one two, and it damps with
`1/(1 + h*c)`; a float program of that (`w_sim.c`) reproduces every digit, 2.2.1's clamp form departs from step 3 (51.9395905).
**Predicted (7.0, `w_sim7.c`)**: y = 50.1598701, 50.5752335, 51.2456779, 52.1707878, 53.3501625. The port: §1.2's loop,
`linearDamping = resistance`, `angularDamping = angularResistance`, 2.2.1's clamp formula, which is 7.0's (read in its island).

### §1.4 Sleeping

Read (7.0): stock 2.2.1 sleep, 1 pt/s, 2 deg/s, `b2_timeToSleep` 0.5 s; no settling logic of PhysicsKit's own.

### §1.5 One animator step: the order

Read (7.0 `_animatorStep:`, `_preSolverStep`, `_postSolverStep`); order measured on the host (`s_anim.m` "A").

```
_ticks += 1; _elapsedTime += dt;                                       // not scaled by speed
pre-solver: if (_needsLocalBehaviorReevaluation) evaluate the item behaviours (§2.5);
            if (implicit bounds && reference system && bounds changed) { take the presentation layer's bounds (view) or
                the layout's; every collision behaviour rebuilds its implicit boundary (§7.4); }
            for (b in _registeredBehaviors) [b _step];                 // only the push behaviour has one (§4.2)
_isInWorldStepMethod = YES; awake = world step (§1.2, write-back inside); _isInWorldStepMethod = NO;
post-solver: _isInWorldStepMethod = YES; begin contacts, then end contacts (§7.5); every action;
            stoppable = every top-level behaviour allowsAnimatorToStop (§8.2); _isInWorldStepMethod = NO;
            run the post-solver blocks; unregister the queued removals, register the queued additions;
            if (stoppable || nothing registered) [self _stop];
private _action; a layout reference: [layout invalidateLayout]; return awake;
```

- `_registeredBehaviors` is an NSMutableSet: `_step` and the actions run in hash order (measured: 8 behaviours added 0..7 ran
  3 2 1 7 0 6 5 4). The port uses one too; no test asserts an action order.
- An action sees the written-back center; collision callbacks come before every action (measured).
- Adding or removing a behaviour inside the step (an action, a delegate callback) is queued to the end of the post-solver;
  adding one queued for removal cancels the removal, and the other way round. World mutations inside the step are queued too.
- Measured: the host's `-_animatorStep:` has type `B24@0:8d16` (a BOOL of one double), what the host test calls.

### §1.6 Running, stopping, the display link, the delegate

Read (7.0):
- `running` = a display link exists. `_tickle` (every parameter change, an item added, `updateItemUsingCurrentState:`)
  starts one if not running and there are bodies.
- `_start` returns if a view reference is gone, a link exists, or **`_disableDisplayLink`** is set (7.0's private
  `-_setAlwaysDisableDisplayLink:`; no delegate call then). Else a CADisplayLink in the common modes, `frameInterval` 1; for a
  view reference `_accuracy` = its window's screen scale (0 -> 1); then `dynamicAnimatorWillResume:`.
- A tick: `dt = timestamp - last`, above 0.5 s taken as 1/60; step; stop if nothing is awake. `_stop` invalidates the link and
  sends `dynamicAnimatorDidPause:`. The delegate's two `respondsToSelector:` are cached at set time.
- Measured (host): with the switch set `running` is 0 and no delegate call comes (`s_anim.m`); without it `willResume` fires
  inside `addBehavior:` (`w_app1.m`). **In a command-line Catalyst process the display link never ticks** (`w_app1`: elapsed 0,
  ticks 0 after 0.5 s of run loop), so the host test sets the switch on both animators and steps them by hand (§12).
- The port starts no display link from `-dealloc`: dissociating the behaviours there tickles, and a link started then would
  outlive the animator (found by the host test; mutant `restart-in-dealloc`, §12).

### §1.7 Resting numbers

Measured (host, `s_anim.m` "C"): an item in an item behaviour only returns NO from the 31st `_animatorStep:(1/60)`; predicted
(7.0) the 32nd. No bodies: NO.

## §2. Bodies

### §2.1 When a body exists

No body until a behaviour using the item is associated (measured, `b_body.m`). **One body per item per animator**, keyed by
`+[NSValue valueWithPointer:item]` (layout attributes: their collection item key); registering it again counts one more
association. Dynamic; measured flags 0x26, 0x2e (bullet) when a gravity behaviour made it, 0x36 with rotation off.

### §2.2 Body creation

Read (7.0 `-_registerBodyForItem:shape:`), in order:
1. Reference-system checks, **`NSInvalidArgumentException`** with the animator's description as the last argument (measured on
   the host, probe `exc.m`; the specification had an internal-inconsistency name, which the host test's T9 corrected):
   `Can't use layout attributes as item (%@) in an animator with view reference %@`,
   `Can't use view as item (%@) in an animator with layout reference %@`,
   `View item (%@) should be a descendant of reference view in %@`.
2. An existing body of another item logs `%@: body %@ without representedObject for item %@`; it is associated and returned.
3. **Bodies live in reference-view coordinates**: a view item's center converted from its superview (measured: (150.3, 50.7) in
   a superview at (10.25, 20.5) -> (160.55, 71.2)).
4. A view's constraints in its superview are removed and `translatesAutoresizingMaskIntoConstraints` set.
5. Size `bounds.size` (origin ignored); zero width or height fails `Invalid size %@ for item %@ in Dynamics`.
6. The §2.3 box (a circle only for a private item-behaviour option); rotation `atan2(t.b, t.a)`, scale and shear ignored.
7. Masks 0, gravity off, a post-step block that writes back (§2.8); into the world; tickle.

### §2.3 The box and the density

Measured (host, `b_raw.m`): `SetAsBox(w/2/ptm, h/2/ptm)`, no inset, radius 0. Read (7.0): inset 2 pt, `w' = (w > 3) ? w - 2 :
max(w - 2, w/2)` (same for h), `_areaFactor = (w*h)/(w'*h')`, `m_radius = 0.001f` set after `SetAsBox`; fixture density =
density * areaFactor, so mass = density * w*h/ptm^2 whatever the inset. 2.2.1's collision is the fork's: polygon-polygon skin
0.002 m, edge or chain a fixed 0.02 m. Measured on the host (T5, §12): in the host build (no skin, full-size box) the port rests at 248.216629, the oracle's to the digit; as shipped (sub-step 0.004 s, box 1 pt inside, skin 0.001 m) the same scene rests at 249.0188141, its bottom 0.98 pt above the floor. That value is the port's own and is pinned to 1e-3 pt by `landing_ios70_test.m` ("T5 as shipped"); it is not a 7.0 measurement, none exists. The 0.8022 pt between the builds is split by three host runs, one shipped constant changed at a time from the host's build: the box inset alone +1.0028 (249.2194214), the sub-step alone -0.2090 (248.0075836), the skin (0.001 m) alone 0.0000 (248.2166290); the three sum to +0.7937, and the 0.0084 left over is the two together, not a fourth constant (shipped minus the sub-step is 249.2194214 too, minus the box 248.0075836, minus the skin 249.0188141: the box adds +1.0112 on the shipped sub-step, the sub-step takes -0.2006 off on the shipped box). Why the skin does nothing here is not explained: a skin of 0.01 m on the host's build also leaves 248.2166290, 0.05 m gives 240.0818787. The sub-step also moves the fall (frame 26: 192.0832977 host, 194.1759491 shipped). The scene of `device/dynamics.m` (a 40x40 view, the reference bounds as the boundary, a loop 1 pt outside them) rests as shipped at a body y of 460.1338806, 0.13 pt past the bounds' bottom, so the view's bottom edge is at the bounds' bottom after the animator's rounding onto the screen's grid: gap 0, not 1 pt (the host's build there gives 0.9987). The earlier "about 1 pt per side, 2.5 pt at rest" was a bound, not a measurement.
Measured masses: 100x100 density 1 -> 1 kg; 200x50 density 3 -> 3 kg, I 1.0625; 1x1 -> 1e-4 (no minimum size).

### §2.5 Material properties, and several item behaviours on one item

Defaults of every body and of a fresh item behaviour (measured): elasticity 0.2, friction 0.2, density 1, resistance 0.1,
angular resistance 0.1, rotation allowed, charge 0, masks 0. Unscaled to restitution, friction, density * areaFactor (with
`ResetMassData`), `linearDamping`, `angularDamping`, `SetFixedRotation(!allowsRotation)`; unclamped (measured: elasticity 5,
friction -2, resistance -1 reach the body; negative density aborts on Box2D's assertion, on the host too).

**Flags, and who wins** (read 7.0; measured `b_props.m`, `b_order.m`): a setter given the value it holds sets no flag;
otherwise it stores, flags the property and asks for re-evaluation. Only flagged properties are pushed, (a) at once for the
behaviour being associated or given an item, and (b) at the start of the next step by every item behaviour in traversal order
(`animator.behaviors`, each followed by its children): **per property the last behaviour that flags it wins** (measured:
X(0.73), then P[c1 0.71, c2 0.72] -> 0.72, even after X = 0.74). Removing an item behaviour resets its bodies to the defaults at
once; the others re-apply at the next step; velocities untouched.

### §2.6 Bullet

The gravity and push behaviours make their bodies bullets; nothing resets it (measured, `b_grav.m`).

### §2.7 Velocities

Measured (`b_vel.m`): `addLinearVelocity:forItem:` of (0, 0) or of an item not in `items` does nothing; associated it adds to
the body at once and wakes it (+(13.37, -7.77) -> (24.3699989, 14.2299995)); not associated it is summed per item and given at
association ((10, 20) + (1, 2) -> (11, 22)), then consumed; the same for angular velocity. The getters answer the body's
velocity when associated and a member, else 0. Rotation off does not stop a spin (2.2.1's `SetFixedRotation`, as the host).

### §2.8 Write-back of center and transform

Read (7.0), identical numbers on the host (`b_wb.m`):
- Every body after each world step; a view item in a view animator converts to its superview.
- Rounded unless `_integralization == 2`, or it is 0 and the item is a plain object. **`_integralization` is 1 only in
  `com.apple.springboard`: 7.0's own rule in its initializer (§9), copied; not a special case of the port's.** In an app views
  are rounded and plain items are not.
- Rounded: s = `_accuracy`; `r(x) = s == 1 ? round(x) : floor(x) + round(s*(x - floor(x)))/s`; the center set only if it
  changed; angle `round(a*5000)/5000`. Unrounded: center and angle as they are.
- **The transform is replaced** by a pure rotation: scale and shear are lost at the first step (measured).
- Positions pass through float ((1.25, 2.5) reads back (1.24999988, 2.49999976)).

### §2.9 updateItemUsingCurrentState: and body lifetime

- No body: nothing. Else center and angle are read, `bounds` is not. A rounded item's position is set only if different after
  pixel rounding, its rotation only if equal after rounding; if only the angle differs nothing happens (measured host quirk,
  `b_upd.m`). Then wake and tickle.
- Each dissociation runs the behaviour's action on the body (gravity off, or item defaults) and counts -1; at 0 the body leaves
  the world at once (after the step inside one). Re-adding makes a new body with velocity 0 (measured).

### §2.10 UIDynamicItemBehavior 9.0: charge, anchored

Measured (host, `s_item.m`); the port's 7.0 class below 7.0 (registry `maximum` 7.0):
- Defaults 0 and NO; flagged as in §2.5, pushed after rotation.
- `anchored` YES: `SetType(b2_staticBody)`, velocity 0, `addLinearVelocity:` without effect; others collide with it as with a
  wall (B at -200 pt/s leaves at +40.0000343). NO: dynamic again, velocity 0.
- `charge` lives in the body object, for the electric and magnetic fields (`UIFieldBehavior.md` §10.2).
- **Removing the behaviour resets neither** (measured), unlike the 7.0 properties. Apple's 7.0-8.x class has neither.

### §2.11 The item behaviour's API

`description`: super, ` E=%f`, ` F=%f`, ` D=%f`, ` R=%f`, ` AR=%f` for each flagged property, ` !Rotation`, the items (read 7.0).

## §3. Gravity (UIGravityBehavior)

### §3.1 Mechanism

Read (7.0), measured (`b_grav.m`): one vector `_gravity` in units of 1000 pt/s^2. Association: `world.gravity = 10 * _gravity`
(m/s^2), then for each item register the body, bullet, `affectedByGravity`, wake. Other bodies do not fall. Acceleration is
mass independent (measured: g = (3, 4) gives +(50, 66.67) pt/s per step for density 1 and 7). Leaving the behaviour clears
`affectedByGravity`; bullet stays; the body coasts.

### §3.2 Several gravity behaviours: one vector, the last writer wins

Measured (`b_grav.m`): adding g2 sets the world to 10 * g2 for every affected body, g1's too; any later setter on any associated
gravity behaviour rewrites it; **removing any gravity behaviour sets the world gravity to (0, 0)**, even with another still in
the animator. `_registerBehavior:` logs `Multiple gravity behavior per animator is undefined and may assert in the future` when
the hierarchy then holds two or more (the string is in 7.0's UIKit, read; printed on the host, measured).

### §3.3 Properties

The state is the vector only. Init (0, 1): angle pi/2, magnitude 1. `gravityDirection` is the raw vector (non-unit kept: (3, 4)
-> magnitude 5, angle 0.927295218). `setAngle:magnitude:` uses `sincosf((float)a)`: `setMagnitude:2` on (3, 4) ->
(1.20000005, 1.60000002). Magnitude 0 gives (0, 0), angle 0, and a later `setAngle:` keeps (0, 0). A setter given the vector held
does nothing; otherwise it stores, rewrites the world at once if associated, and tickles.

## §4. UIPushBehavior

Read (7.0), measured (host, `s_push.m`).

### §4.1 Construction and properties

`init` works (Continuous, active). Vector and (angle, magnitude) are kept apart: `setPushDirection:` derives angle and
magnitude, `setAngle:magnitude:` the vector with `sincosf((float)a)`. Measured: (3, 4) -> 0.927295218 and 5; magnitude 0 ->
(0, 0) with the angle kept; magnitude 2 -> (1.20000005, 1.60000002); angle pi -> (-2, -1.74845553e-07);
`setAngle:1 magnitude:-1` -> (-0.540302277, -0.841470957). Offsets are keyed by the item pointer; items get bullet bodies.

### §4.2 Force application

In `_step` (§1.5): continuous `ApplyForceToCenter(v)`, or `ApplyForce(v, (center + offset)/ptm)` (offset not rotated);
instantaneous `ApplyLinearImpulse`, then `active = NO`. SI units as given. Forces are cleared after the whole sub-step loop, so
a continuous push acts in every sub-step. Measured (1 kg): continuous (1, 0) vx 0.833333373, 2.50000024, 4.16666698,
5.83333349; instantaneous 100 pt/s; offset (0, 50): w -0.0250000022, -0.075000003, -0.125000015, -0.175000027 rad/s; impulse
(0, 1) at (50, 0): dw 3.00000007; 200x50 density 2 (2 kg), impulse 0.3: 15.000001 pt/s.

## §5. UISnapBehavior

Measured (`j_snap1`-`j_snap5`), read (7.0; the host's has the same shape).
- `-init` raises `NSInvalidArgumentException` `init is undefined for objects of type UISnapBehavior`. Defaults: damping 0.5,
  distance D = 50 pt, 4 Hz.
- Association: the item's shared body, a static anchor body at the point (angle 0, masks 0), and four distance joints item ->
  anchor with local anchors (-hw, -hh)->(-hw - D, -hh), (-hw, -hh)->(-hw, -hh - D), (hw, hh)->(hw + D, hh), (hw, hh)->(hw, hh + D)
  (hw, hh: half the bounds), `dampingRatio` = damping at association, 4 Hz. `Initialize` from the current points makes the
  first lengths the current distances; then **`dispatch_after(DISPATCH_TIME_NOW + 0, main queue)` sets all four to D**, so the
  rest length holds only after the next main-queue turn (measured: stepping before a run-loop turn moves nothing).
- Equilibrium on the point at angle 0 (measured (299.999969, 199.999222)). `setDamping:` only stores (a live snap keeps 0.5).
- 9.0 `snapPoint` (the port's class below 7.0): moves the static anchor, wakes the item; joints and rest lengths stay.
- Trajectory (measured `j_snap3.m` against a Box2D model): 100x50 (100, 100) -> (300, 200), damping 0.5, frame 1 Apple
  (113.265648, 106.623589, 0.0361267589), model (113.265648, 106.623589, 0.0361267552); **residual 1.364e-4 pt, 1.28e-6 rad**.

## §6. UIAttachmentBehavior and its 9.0 members

Read (7.0), measured (host, `s_att.m`, `s_anim.m` "D").

### §6.1 Construction

- `-init` raises `NSInvalidArgumentException` `init is undefined for objects of type UIAttachmentBehavior` (measured).
- Anchor initializers: one item, `_anchorPointA` = the offset, private `type` 1. Item initializers: two items, both offsets,
  `type` 0. Nothing else is set: length, damping and frequency answer 0 before association (measured).
- **`attachedBehaviorType` answers `UIAttachmentBehaviorTypeItems` (0) for every 7.0 initializer, an anchor one too**: no 7.0
  initializer sets it (measured: 0 for `initWithItem:attachedToAnchor:`). The private `type` is what reads 1.

### §6.2 Association and the joint

Association registers the bodies (or a static 1x1 pt anchor body at the point, masks 0), then `_reevaluateJoint`: a distance
joint with the offsets as body-local anchors (an offset turns with its item), damping and frequency only if set,
collideConnected for two items; `Initialize` makes the length the current distance; a set length is applied on the live
joint; **an anchor end closer than 1 pt, rigid and with no length set, becomes a revolute joint at the anchor**. Frequency 0
is a rigid rod. Measured (item 100x100 at (100, 100) rotated 0.3): anchor (100, 300): length 200; offset (10, 20): 1.77975357 m;
two items: collideConnected, 2.00997519; anchor 0.5 pt off: revolute, reference angle -0.299999982.

### §6.3 Getters and setters

`length`, `damping`, `frequency` answer the live distance joint, else the ivar (measured 200 right after association).
`setAnchorPoint:` moves the static anchor, the rest length stays. `setLength:` from or to 0 rebuilds the joint; otherwise
7.0 applies it with **`dispatch_after(DISPATCH_TIME_NOW + 1 ns, main queue)`** (read), where the host applies it at once
(measured); the port does 7.0's and the host test turns the run loop before it looks. `setDamping:`/`setFrequency:` set the
live joint (a frequency from or to 0 rebuilds it) and wake both ends.

### §6.4 9.0 members (the port's 7.0 class below 7.0)

Measured (host, `s_att.m`); 7.0 has none. No factory's joint collides its bodies; P in reference coordinates. (A rotated 0.3 at
(100, 100), B at (300, 120), P (200, 50).)

| factory | 2.2.1 joint | measured |
|---|---|---|
| fixed | weld, `Initialize(bA, bB, P/ptm)`, rigid | lA (0.807576418, -0.773188472), lB (-1, -0.699999928) |
| pin | revolute, `Initialize(bA, bB, P/ptm)` | same anchors, no limit, no motor |
| sliding, two items | prismatic, `Initialize(bA, bB, P/ptm, normalize(v))` | axis (3, 4) -> local (0.809618115, 0.586957097) |
| sliding to an anchor | prismatic to a static body at P | axis (0, 2) -> (0.295520216, 0.955336511) |
| limit | rope, anchors `c - o`, `maxLength = |wB - wA|` (M4) | **offsets negated, in world axes** (host quirk); maxLength 2.10535026 m |

- **`attachedBehaviorType` of the sliding-to-anchor factory is Items (0)**: the host test's T12 read 0 on the host; the
  specification's 1 was the private `type`. The port answers 0 and keeps `type` 1.
- Defaults: `frictionTorque` 0; `attachmentRange` infinite for sliding and pin, zero otherwise; `length` 0, for limit the
  centres' distance at the factory (200.997512).
- `setAttachmentRange:` pin: limit in radians; sliding: in points / ptm; ignored otherwise. `setFrictionTorque:` pin: motor at
  speed 0 with max torque t; ignored otherwise. Set before association they apply when the joint is made (`s_misc.m`).
- Host bug not copied: `length`/`damping`/`frequency` of an associated 9.0 attachment raise `-[PKPhysicsJointWeld damping]:
  unrecognized selector` on the host; the port answers the ivars (a limit's `length`: its maxLength, as the host does, M4).
  `setLength:` on a limit leaves the limit, as the host.
- `UIFloatRangeZero` {0, 0} and `UIFloatRangeInfinite` {-inf, +inf} are exported data (read with lldb on the host);
  `UIFloatRangeIsInfinite` is an exported function, `minimum <= -FLT_MAX && maximum >= FLT_MAX` in double, so {-1e39, 1e39}
  is infinite and a NaN at either end is not (host listing: `fcmp` with -3.4028234663852886e38, `cset ls`; `fcmp` with
  3.4028234663852886e38, `csel lt`); `UIFloatRangeMake` and `UIFloatRangeIsEqualToRange` are static inline in the header.
  Code: `UIKit/UIFloatRange.m`, a file of its own (9.0 exports, needed where the 7.0 files are left out).

## §7. UICollisionBehavior

### §7.1 Collision groups

Read (7.0), measured (`c_masks.m`): association takes `g = ++animator counter`, dissociation `--counter`: a counter, not an
allocator. `_groupVID = 1u << (2g)`, `_groupBID = 1u << (2g + 1)`, shift mod 32 as arm64 and the host do (`& 31` in the port;
armv7's `LSL` would give 0 from the 16th group). First behaviour 0x4/0x8, second 0x10/0x20, the 16th wraps to 0x1/0x2.
**Measured consequence, reproduced**: add c1, add c2, remove c1, add c3 -> c3 has c2's bits and their items collide;
c1 re-added gets 0x40/0x80. Before association both are 0.

### §7.2 Masks

```
own = edge ? BID : VID;  modeM = Items ? VID : Boundaries ? BID : VID | BID;  both = VID | BID;
coll = body.collision & ~both;
on:  coll |= modeM; collision = coll; category = (category & ~both) | own; contactTest = coll;   // overwritten, not OR-ed
off: collision = coll; category &= ~both; contactTest = coll;
```

Items get `isEdge:NO`, the implicit and every explicit boundary `isEdge:YES`; another behaviour's bits on a shared body stay
(measured: B in c1 Everything and c2 Items: 0x14/0x1c/0x1c). Default mode Everything = NSUIntegerMax. Measured with c1:
Everything item 4/0xc/0xc, boundary 8/0xc/0xc; Items 4/4/4 and 8/4/4; Boundaries 4/8/8 and 8/8/8.

### §7.3 Contact filter and response

Measured (`c_filter.m`), SpriteKit's semantics, not b2Filter's: a contact exists iff `(catA & collB) || (catB & collA)`; body X
responds iff `catOther & collX`; one that does not respond is unaffected and the other sees it as immovable. In Items mode with
the reference bounds and a boundary the item **falls through both, and the delegate still hears began/ended** (y 2264.79 after
2 s); Boundaries or Everything: it rests (center 418.342499). With unmodified 2.2.1 (16-bit b2Filter): the 32-bit masks live in
the body object; a `b2ContactFilter::ShouldCollide` with the rule above; `PreSolve` disables the contact when no dynamic body
of the pair responds (Box2D still reports begin and end). **Refusal**: one-sided response between two dynamic bodies cannot be
expressed in the unmodified solver; UIKit's masks produce it only through the counter reuse of §7.1 (same bits, different
modes).

### §7.4 Boundaries

Read (7.0), measured (host, `c_bounds.m`):
- Static bodies at the origin; a line is a `b2EdgeShape`, a path or rect a `b2ChainShape::CreateLoop`, `m_radius = 0.001f`;
  fixtures friction 0.2, restitution 0.2; velocity threshold 1 m/s.
- Flattening: the first subpath only; a curve of polyline length L makes `max((int)(L / 10.0f), 1)` segments; in metres a point
  within 1.42108547e-14 m^2 of the previous one is dropped, and the last if equal to the first. Degenerate paths: M2.
- Implicit boundary: none without a reference system; else `UIEdgeInsetsInsetRect(bounds, insets)` outset by 1 pt (measured
  (5, 7, 320, 480) with 10/20/30/40 -> (24, 16)-(286, 458)); refreshed each step from the presentation layer (§1.5).
  `translatesReferenceBoundsIntoBoundary` resets the insets to 0.
- Explicit: nil identifier or path ignored; the body is made at add; **a second add under one identifier leaves the old body
  in the world, colliding** (measured, reproduced); `boundaryWithIdentifier:` answers a new path each call;
  `removeAllBoundaries` keeps the implicit one; `setCollisionMode:` re-applies the masks.

### §7.5 Contacts

Read (7.0 PhysicsKit's listener), over 2.2.1: `BeginContact` makes a record keyed by the `b2Contact *`, `PostSolve` keeps the
manifold point of the largest normal impulse (first on ties) in points, `EndContact` marks it; after the sub-step loop the
records go to the animator. In the post-solver every collision behaviour gets the begin contacts, then the end ones: **all
began callbacks precede all ended ones, and both precede the actions**. A behaviour reports a contact of its own items, with
another of its items, its implicit boundary (identifier nil) or one of its explicit boundaries. Measured (`c_contacts.m`): an
item-item contact is reported by every behaviour holding both, whatever its mode.

## §8. UIDynamicBehavior and the behaviour hierarchy

Read (7.0), measured (host, `s_anim.m` "C", "D").

### §8.1 Primitive and composite

`-init` makes a composite; the 7.0 classes are primitive. A primitive has items, a composite children, never both: so
`addChildBehavior:` on a gravity behaviour is a silent no-op and `childBehaviors` is empty (measured); `items` of the base class
is nil. `description`: super + ` (Stoppable)` if `allowsAnimatorToStop` + ` (A)` with an action.

### §8.2 Children and association

- `addChildBehavior:` while associated checks and registers the child at once; else it waits in `_addedBehaviors`.
- The base `_associate` registers the waiting children; the base `_dissociate` puts every child back into `_addedBehaviors`
  and unregisters them.
- `_changedParameterForBody:` wakes the body and tickles.
- `allowsAnimatorToStop` (private): primitive NO; a composite without children: no action; with children: all of them allow it
  (the action ignored). Measured: gravity 0, empty composite 1, with an action 0, with a gravity child 0.

### §8.3 The animator's side

`addBehavior:` of nil or a top-level behaviour returns; one already registered (a child somewhere) raises
`NSInvalidArgumentException` `Adding the same behavior twice to the same animator is not supported %@` with its description
(measured). `_registerBehavior:` (queued inside a step): world, context, `willMoveToAnimator:self` (with `dynamicAnimator`
set), associate, into the set; item behaviour -> re-evaluate; gravity -> the §3.2 log; tickle. `removeBehavior:` acts on
top-level behaviours only; `_unregisterBehavior:` and `removeAllBehaviors`: M1. `behaviors` is the top level in add order.

## §9. UIDynamicAnimator public API, the list of animators, the resize wake

Read (7.0 `-initWithReferenceSystem:`), shared by the three initializers:
- A view: bounds its bounds, the view marked a reference view. A layout: bounds `(0, 0, collectionViewContentSize)` (7.0's
  private `-[UICollectionViewLayout bounds]`, which 6.x lacks: computed). nil: CGRectNull (measured).
- `_accuracy` = main screen scale; **`_integralization = [bundleIdentifier isEqualToString:@"com.apple.springboard"] ? 1 : 0`**:
  7.0's own rule, copied as it is (§2.8).
- **On the main thread `+_registerAnimator:self`**, the list `+_referenceViewSizeChanged:view` walks to tickle every animator
  whose reference view is `view` (the boundary is rebuilt in the next step). The port keeps a non-retaining list of the
  animators made on the main thread; one leaves it in `-dealloc`. **The specification had called this wake lost on iOS 6;
  M3 measured it: the port observes the reference view's `frame` and `bounds` (M3).**
- `elapsedTime` = the sum of the dt given (measured 0.0666666667 after 4 steps of 1/60), never reset.
- `description` (measured, `desc.m`): `<UIDynamicAnimator: p> Stopped (0.250000s) in <UIView: p> {{0, 0}, {400, 300}}`,
  `Stopped ` only while no display link runs; nil reference `<(null): 0x0>` with CGRectNull.
- `itemsInRect:` queries Box2D's fat AABBs (+10 pt): measured (50x50) a rect 9.9 pt away returns the item, 10.5 pt does not;
  with 7.0's box the limit is 9.1 pt.

## §10. Protocols

- `UIDynamicItem` (7.0): `center` (get, set), `bounds` (get), `transform` (get, set); 9.0 optional `collisionBoundsType`,
  `collisionBoundingPath` (`UIFieldBehavior.md` §13). The animator reads center and transform at body creation and in
  `updateItemUsingCurrentState:`, `bounds.size` at creation only; it writes center and transform after every step.
- **UIView adopts `UIDynamicItem`** in 7.0. Its three members are UIView's own since 2.0; UIView implements none of the 9.0
  optional ones on 6.1.3, 7.0, 8.4.1 or 9.0 (measured, `objc.inventory` of the armv7 caches). The conformance is declared in
  `UIDynamicAnimator.mm`, so a band whose release has Dynamics leaves it out with the class.
- `UICollectionViewLayoutAttributes` has no 2D `transform` on iOS 6 (7.0 added it).
- `UIDynamicAnimatorDelegate` (§1.6), `UICollisionBehaviorDelegate` (§7.5).
- `UIPushBehaviorMode` Continuous 0, Instantaneous 1; `UIAttachmentBehaviorType` Items 0, Anchor 1; `UICollisionBehaviorMode`
  Items 1, Boundaries 2, Everything NSUIntegerMax (measured).

## §11. Implementation rules and the named divergences

The world belongs to the animator (§1.1, forces not auto-cleared); a body object per item holds the `b2Body`, the item, the
association count, gravity scale 1 or 0, the three 32-bit masks, charge and the area factor; `b2BodyDef` dynamic, damping
0.1/0.1, sleep allowed, awake, gravity scale 0; one fixture, the §2.3 box, friction 0.2, restitution 0.2. Departures from 7.0:
1. **Degenerate boundary paths** raise the host's exception where 7.0 aborts on an assertion (M2).
2. **Host-only exceptions** are copied only where a section says so (the reference-system ones, §2.2).
3. **One-sided response** between two dynamic bodies is not expressible (§7.3).
4. Withdrawn: the idempotent `removeAllBehaviors` (M1) and the lost resize wake (M3).

## §12. The host test and its negative controls

`sh tests/backports/host/dynamics/run.sh` (about a minute) compiles the Dynamics sources for Mac Catalyst with their classes and
exported symbols renamed `CharonHost...` (`tests/backports/host/uikit2/renames.sh`: `-D` flags from `nm`, selectors kept), so
the host's animator (the oracle) and the port run side by side over the recipe's unmodified Box2D, `.mm` compiled as the
package does (`-fno-rtti -fvisibility-inlines-hidden`). Built twice: with `CHARON_HOST_DIFFERENTIAL` (§0) for the comparisons
with the host, and as shipped for the 7.0 predictions (`*_ios70_test.m`). Both animators have the display link switched off and
are stepped by hand, the host's through its private `_animatorStep:` and read through its private accessors: test code only.
The port is compared with the oracle live, the oracle with the numbers its probe measured.

| row | scene | tolerance |
|---|---|---|
| T1, T1b | fall, resistance 0 and 0.1 (§1.3) | 1e-4 pt; T1b carries the damping formula's 4e-6 pt |
| T1c | the same, as shipped, against the 7.0 prediction (§1.3): `w_sim7.c`, this band's own float simulation of its reading of 7.0's listing, **not a 7.0 measurement** (no 7.0 device is in the fleet) | 1e-5 pt |
| T2 | push continuous, instantaneous, offset, impulse (§4.2) | 1e-5 relative |
| T3 | push algebra (§4.1) | exact |
| T4 | pendulum, 40x40 at (200, 100), anchor (100, 100), gravity, resistances 0: f1 (199.999969, 100.069443), f10 (199.132126, 113.146225), f30 (139.359573, 191.92836), f60 (2.06188917, 120.202171), length 100 (`s_oracle.m`) | 0.05 pt at f30, 0.5 pt at f60 |
| T4b | spring, 40x40 at (100, 250), anchor (100, 100), 2 Hz, damping 0.3, length 100 set first: f1 (100, 249.48938), f10 (100, 201.092148), f30 (100, 204.031586), f60 (100, 200.142715) (`s_oracle.m`) | 0.05 pt |
| T5 | 100x100 at (100, 100), elasticity 0, resistance 0, onto a boundary at y 300 (`s_oracle.m`): f26 192.083298, f27 199.374969, f28 206.944397, rest 248.216629 | 1e-3 pt, before contact and at rest (§2.3) |
| T6 | snap (§5) | 2e-4 pt |
| T7 | collision masks and the group counter (§7.1, §7.2) | exact |
| T8 | world gravity of several gravity behaviours (§3.2, §3.3) | exact |
| T9 | exception names and texts (§2.2, §5, §6.1, §8.3) | exact |
| T10 | step order: write-back before actions, contacts before actions, deferred add and remove (§1.5) | order only |
| T11, T12 | attachment geometry, the 9.0 factories (§6.2, §6.4) | 1e-4 pt, 1e-6 |
| T13 | anchored, charge (§2.10) | exact |
| T14 | `itemsInRect:` gaps 8 (in) and 11 (out) (§9) | |
| T15 | resting stop on the 31st call (§1.7) | 1 call |
| T16 | `elapsedTime` after 4 steps | exact |
| T17 | several item behaviours, reset on removal (§2.5) | exact |

Groups and counts, measured 2026-09-24 on this host: `fall_ios70` 5/5 (T1c), `structure` 203/203 (T3, T7-T14, T17 and an
animator released while its display link could start), `trajectory` 100/100 (T1, T1b, T2, T4, T4b, T5, T6, T15, T16), `wake` 16/16 (M3; 2026-09-26).

**Negative controls**, `sh tests/backports/host/dynamics/mutants.sh`: each mutant of a copy of `UIKit/` must fail its group.
Measured: a wake on any change of the frame or bounds (not only of the size) -> `wake` fails 2 checks; the bounds observer
without the prior option -> `wake` fails 1; the exception name made internal inconsistency -> `structure` fails; gravity scale
10 -> 10.5 -> all three fail; the 7.0 sub-step 0.004 -> 0.005 -> `fall_ios70` fails; no restart guard in `-dealloc` -> `structure` aborts (exit 134).

**Not covered by the host test**: the display link's cadence (§1.6), 7.0's own numbers other than T1c's prediction, and anything on a device.

## §13. Open

- Every 7.0 number (§1.3, §1.7 and the as-shipped rows) is a prediction from the listing, not a device measurement.
- The limit attachment's length at the factory against at association: settled by M4.

## M1. removeAllBehaviors with a hierarchy

Measured (host, `m_rab.m`, `m_rab2.m`), read (7.0).
- **M1a, outside a step**: over a copy of the registered set each behaviour is dissociated and its context cleared, then both
  lists emptied. A child is dissociated twice, through its parent with its context set and directly with context nil, which
  only messages nil: nothing is destroyed twice. `running` stays 1 until the next step pauses it; re-adding works.
- **M1b, from an action**: every registered behaviour is queued and unregistered at the end of the post-solver, **but
  `animator.behaviors` is not emptied**: a later `addBehavior:` of them is a silent no-op.
- **M1c**: a nested composite re-added after it raises `Adding the same behavior twice ...` (7.0 too).
- **M1d**: 7.0 and the host differ only in the host's `willMoveToAnimator:nil` in the loop. `_unregisterBehavior:` outside a
  step has **no "is it registered" check** (the specification's §8.3 had one); inside a step it queues only a registered one.
- The port: 7.0's loop without `willMoveToAnimator:`, every `_dissociate` safe with a nil context, no idempotence flag.

## M2. Empty or degenerate collision boundary path

Measured (host, `m_path.m`): empty, moveTo-only and three coincident points raise `NSInternalInconsistencyException`
`invalid path for collision boundary`, at add when the behaviour is associated, else at the later `addBehavior:`, which leaves
it in `animator.behaviors` with its context set but not registered; the identifier stays and `boundaryWithIdentifier:` answers
the path. Two points (with or without close) are accepted as the loop v0 v1 v0: contacts are reported and **the item falls
through**. Three collinear points or a triangle: the item rests. A nil path is ignored. Host rule (its `addEdgeLoop`, read):
drop near-duplicates, fail at one point or none, drop trailing points equal to the first, fail below 2.
**7.0 aborts instead** (read: its `CreateLoop` asserts `count >= 3`) for every path under 3 points; the port raises the host's
exception (§11). For 2 points, where unmodified 2.2.1's `CreateLoop` asserts, the port builds what the host stores:
`CreateChain({v0, v1, v0}, 3)` with previous and next vertex v1 (from the 2.2.1 source, not measured).

## M3. Wake of a paused animator when the reference view is resized

Measured (host, `m_wake.m`): a reference view 300x400 in a 600x800 superview, a 40x40 item under gravity with the reference
bounds as boundary, settled at y 379.58139 and paused; KVO observers on the view's `bounds` and `frame` and the layer's `bounds`
and `position`; then the view resized to 300x600. (No window can be made in a command-line Catalyst process, so the probe
answers the model layer for a nil presentation layer and drives the tick by hand.)

| path | `_referenceViewSizeChanged:` from | wakes | KVO fired |
|---|---|---|---|
| (a) `view.frame =` | `-[UIView setFrame:]` | yes, inside the setter; the item falls to 579.340698 | layer position, layer bounds, view frame, **not view bounds** |
| (b) `view.bounds =` | `-[UIView setBounds:]` | yes | layer bounds, view bounds, **not view frame** |
| (c) `view.layer.bounds =` | no | no (moves only after another change wakes it) | layer bounds |
| (d) `view.layer.frame =` | no | no | layer position, layer bounds |
| (e) superview resized, autoresizing | `setFrame:` from the autoresizing | yes | layer position, layer bounds, view frame |
| (f) Auto Layout constant 400 -> 600 | `setBounds:` from the layout engine | yes | layer bounds, view bounds, layer position |
| (g) center, (h) transform, (i) layer position | no | no | |

Read (7.0): the animator marks its reference view (`_registerAsReferenceView`, a view flag); `-[UIView setFrame:]` and
`-setBounds:` call `_notifyReferenceViewSizeChange` only when the bounds size changed, and it calls
`+[UIDynamicAnimator _referenceViewSizeChanged:]` for a marked view: the only two callers, no layer-side hook.

**Measured on emulated 4.3, 5.1.1, 6.0 and 6.1.3** (`xmake emulate -d iPhone3,1 -r 4.3` and `-r 5.1.1`, `-d iPhone4,1 -r 6.0` and `-r 6.1.3`, `tests/backports/device/uiview-kvo.m`: a command-line program, no `UIApplicationMain`; the same
nine paths, with `-[UIView setFrame:]` and `-setBounds:` counted by a probe-only wrap and KVO on the view's `frame` and `bounds`
with the prior option):

| path | `setFrame:` / `setBounds:` calls | size changed | KVO fired |
|---|---|---|---|
| (a) `view.frame =` | 1 / 0 | yes | frame |
| (b) `view.bounds =` | 0 / 1 | yes | bounds |
| (c) `view.layer.bounds =`, (d) `view.layer.frame =` | 0 / 0 | (layer only) | neither |
| (e) superview resized, autoresizing | 1 / 0 | yes | frame |
| (f) Auto Layout constant 400 -> 600 | 0 / 1 | yes | bounds |
| (g) center, (h) transform, (i) layer position | 0 / 0 | no | neither |

The table is the same, row by row, on all four releases; (f) is not run on 4.3 and 5.1.1, which have no `NSLayoutConstraint` (6.0 and later do), and the probe says so instead of measuring it. So on 6.1.3 KVO of `frame` together with `bounds`, each with the prior option (the bounds size read in the prior notification,
compared in the one after), fires on exactly the calls that wake on 7.0: the same set as the host's table above, and the
size-changed test is 7.0's own (the prior/after comparison came out 1 wake per wake path and 0 for the rest, `priors` 1 per
setter call).

**Lifetime on 4.3, 5.1.1, 6.0 and 6.1.3** (`uiview-kvo.m`, the same runs). An observer left on a view that deallocates: the process lives, and KVO logs
`An instance ... of class UIView was deallocated while key value observers were still registered with it. Observation info was
leaked, and may even become mistakenly attached to some other object` with the observation info; 400 views made after it saw
no stray callback, but the log line is KVO's own report of a defect. An observer removed by an object the view holds
(`objc_setAssociatedObject`, released while the view deallocates, its `-dealloc` calling `removeObserver:forKeyPath:` on the
view): no log line, no exception, the removal works in the middle of the view's deallocation; and the same object released
early (association set to nil on a live view) removes the observers, the view then moves with no callback and deallocates
without a log line. That is the same on all four releases: one KVO line per run, the control's, none for the remover's view or the early release, 0 stray callbacks in 400 new views. Order matters on 5.1.1: with the leaking control run first (the probe's first order), the run logged the leaked observation three times, all three naming one instance and one observation info, and the early-release view got 2 callbacks after its observers were removed (read as the leaked observation staying with the address and reaching the next views built there; not taken further); the probe now runs the control last, and the four numbers above are from that order. So the lifetime is solved by the public runtime API and no swizzle is needed, and an observer left on a dying view is worse on 5.1.1 than a log line, which is the reason to remove it before the view goes.

**The port**: `UIDynamicAnimator.mm`'s `CharonReferenceViewWatch`, one per reference view, held by the view (associated object)
when an animator on the main thread lists it; it observes `frame` and `bounds` with the prior option and tickles the animators
whose reference view it is when the bounds size differs. It goes with the view, or when the last animator over that view
deallocates. Autoresizing and Auto Layout reach it through the same two setters, as on 7.0. Covered by the host test `wake`
(§12; its two mutants in `mutants.sh`); the numbers above are the emulator's, not a device's.

**The shipped watch, on 4.3, 5.1.1, 6.0 and 6.1.3** (`tests/backports/device/dynamics-watch.m`, `charon@apple-backports` with `uikit` linked and `apple_minimum` set to each release, `xmake emulate -d iPhone3,1 -r 4.3|5.1.1|6.0` and `-d iPhone4,1 -r 6.1.3`; the probe's own observer above is not the port's, this runs `CharonReferenceViewWatch`; the target waives `charon.waive.weak-imports`, since the release refuses the libraries' weak imports of `NSProgress`, `NSUUID`, `NSTextContainer`, `NSByteCountFormatter` and, on 4.3, `CFRunLoopObserverCreateWithHandler`, none of which this program reaches): on 5.1.1, 6.0 and 6.1.3 a resting animator wakes on (a) `view.frame`, (b) `view.bounds` and (e) autoresizing, and not on (c) layer bounds, (g) center or (h) transform; with the animator released first and then the view, with the view released first and the animator alive (its `referenceView` is nil after), and with two animators over one view of which the first is released (the second still wakes), the view deallocates each time when the run says it does (a counting subclass) and the log has no `was deallocated while key value observers were still registered` line and no other line of the animator's; 400 views made after saw nothing. 0 failed checks on all three, so 5.1.1, where a leaked observer does damage (the probe's control above), leaves nothing behind. On 4.3 the lifetimes are the same and clean, 0 failed checks and no such line; the wake checks are not made there, because there is no display link to start: the watch asks the public `[[UIScreen screens] count]` after its first view is made, and it is 0 on 4.3 and 1 on 5.1.1, 6.0 and 6.1.3, so on 4.3 the animators are kept from starting a display link and the program prints seven `skip` lines and, as its last line, `0 checks failed, 7 skipped`.

What a process finds, from `tests/backports/device/display-probe.m` (built by `display-probe/xmake.lua`, run by `display-probe/run.sh`; emulated iPhone3,1, 68 runs of 2026-09-27 with the addon v0.8.10 (a re-run of the 6.0 and 4.3 cells with v0.8.11, 12 runs, answered the same), the logs were kept in the charon checkout's `.agent-work/handoffs/2026-09-27-below6-display-probe/` and were deleted on 2026-10-05 with no copy left, so the table below is the only record of them until the probe is run again; one line each: `[UIScreen screens]`, then the display link):

| release | what changes the answer | screens, then `-[UIScreen displayLinkWithTarget:selector:]` |
|---|---|---|
| 4.3 | nothing tried: bare, a UIView, a UIWindow made key and visible, that and a run loop turn of 0.5 s, a UIView and 30 s of run loop turns, the first eight with `apple_minimum` 4.3 and with `charon@apple-backports` linked and not, the last without | 0 in all 9 runs; the call **faults** (SIGSEGV, address 4, QuartzCore `+0x9680e` in `+[CADisplayLink(CADisplayLinkPrivate) displayLinkWithDisplay:target:selector:]`, called from `+[CADisplayLink displayLinkWithTarget:selector:]` at `+0x96891` and from `-[UIScreen displayLinkWithTarget:selector:]` at UIKit `+0x1f01f1`); the class call faults the same (the first session's runs, `d1-first-session/` beside the others) |
| 5.1.1 | not the mode and not the build: the same binary, `apple_minimum` 4.3, no package, three bare runs gave 1, 0, 1 screens, three with a UIView gave 0, 0, 0, four more with a UIView from an earlier build of the program (`probe4-out-5.1.1-repeat.txt` beside the other logs; each made its view, whatever the run's label said) gave 1, 0, 0, 0, and the first session, of the same program, the opposite (bare faulted, with a view one screen); 30 s of turns after a view did not bring one in 3 runs of 3 | 1 screen: a link. 0 screens: the same fault (QuartzCore `+0x541d0`, UIKit `+0x129961`). With `charon@apple-backports` linked at `apple_minimum` 5.1.1, all 4 modes gave 1 |
| 6.0 (iPhone3,1 and iPhone4,1) | only the package with `apple_minimum` 6.0: with it that gives 1 screen and a link, bare or with a view; `apple_minimum` 6.0 without it, and `apple_minimum` 4.3 with it, give 0 | 0: the link is **nil**, no fault. 30 s of turns after a view: 0, nil |
| 6.1.3 iPhone3,1 | the same as 6.0: only the package with `apple_minimum` 6.1.3 gives 1 | as 6.0; 30 s: 0, nil |
| 6.1.3 iPhone4,1 | a UIView also gives 1 without the package; bare, only the package does (both minimums) | 0: nil; 1: a link |

Read: `[UIScreen screens]` agreed with the link's outcome in every one of the 68 runs (0 with a fault below 6.0 and nil from 6.0, 1 with a link), so the public route is the predicate, and the private `+[CADisplay mainDisplay]` it replaces is not needed: it is nil where `screens` is empty in 37 of the 43 runs with none, and an object in the other 6 (one 5.1.1 run with a window and a turn, and the 30 s runs on 5.1.1 (3), 6.0 and 6.1.3, 4.3's staying nil), where `screens` was still 0 and the link faulted or was nil, so it is the worse predicate of the two. What it is not: a property of the release. The two differences the review named between the first probe and the watch, the binary's `LC_VERSION_MIN_IPHONEOS` (the probe had 4.3, the watch its release) and the linked package, were tried in a 2 x 2 on 6.0 and 6.1.3: `apple_minimum` 6.0 or 6.1.3 without the package gives no screen on either (0, iPhone3,1); with the package it gives 0 at `apple_minimum` 4.3 and 1 at the release's own, bare, so before `main`; and on 6.1.3/iPhone4,1 a view suffices as well (the first session's probe on 6.1.3 ran on iPhone3,1, the watch's on iPhone4,1; that is one more difference between them). The package installed is the same in both packaged cells: the deb's `postinst` picks the band by the device's `ProductVersion` (`bands/ranges`), so the emulated 6.0 loads `bands/6.0` in the cell at `apple_minimum` 4.3 as in the one at 6.0 (in the rootfs of each, `libUIKitBackports.dylib` is a link into `bands/6.0`), and `otool -ov` of the two debs finds the same initialisers in both, 37 classes with a `+load` in UIKit's library and 8 in Foundation's. What differs between the two cells is the minimum OS the binary and the libraries carry (`LC_VERSION_MIN_IPHONEOS` 4.3 or 6.0), which `apple_minimum` sets for both at once, so **this 2 x 2 does not say which of the two decides**; a cell with the binary at 6.0 and the libraries at 4.3, or the reverse, would, and was not run. (Measured from the deb of `probe8`: the 4.3 band is 507840 + 217456 bytes for UIKit and Foundation, 725 KB, with 10 + 1 classes that have a `+load`; the 6.0 band 1836704 + 672512, 2.51 MB, with 37 + 8; a device or an emulated release loads the band of its own version, so the 4.3 band is loaded by 4.3 to 4.3.5 only.) Why the release's own process gets no screen on 6.x is not found: the runs that find a screen with the package took 1.7 to 5.0 guest s in all, against 0.1 to 0.6 s of a run that finds none on 6.0 and 6.1.3/iPhone3,1, and the runs that wait 30 s after the first question find nothing, so what is missing is at the process's first connection, not after it; that is a reading, not a run. On 5.1.1 the same binary answers 0 or 1 from run to run, which is the same kind of difference with nothing to vary. So in the watch's own process (the package at its release's `apple_minimum`, linked) the answer is 0 on 4.3 and 1 on 5.1.1, 6.0 and 6.1.3 in every run, and for any other process it is what it finds.
On 4.3, then, no process the emulator can make has a display: a view, a window, a run loop turn and 30 s of them leave `screens` at 0, and an application started through `UIApplicationMain` as the emulated command does not reach `application:didFinishLaunchingWithOptions:` (the run is `boot-blocked`, SpringBoard and locationd waiting 88 guest s, as the `emulate-port` skill says of an application started by `run` on any release). Whether an application started by SpringBoard on a device or on a boot that goes through it has a display on 4.3 is **not measured**; the wake checks have never run on 4.3, on the emulator or a device, and the last line of the watch says so (`N checks failed, M skipped`; the run's `pass` is the exit status).

What the run found, and the port's fix: below 6.0 the animator called `-constraints` and `-setTranslatesAutoresizingMaskIntoConstraints:` on the item's view (`unrecognized selector`, the first `addBehavior:` on 4.3 and 5.1.1), now behind `respondsToSelector:`; and an animator released while behaviors were added on 4.3 was autoreleased by the behaviors' `-charon_context` inside its own `-dealloc` (retained and autoreleased, no handshake below 5.0 cancels the pair), so the pool later released freed memory (`__NSAutoreleaseFreedObject(): release of previously deallocated object`), now released in a pool of the dealloc's own; measured clean on 4.3 for gravity, push, snap, both attachments, both collisions, an item behavior and a composite with children. Not measured: (f) on the shipped class, and the wake checks on 4.3, where nothing the emulator can start gives the process a display (above); that a 4.3 application on a device has one is not measured either.

**Retracted**: the port first wrapped the two setters with `method_setImplementation`, on the reading that KVO of `frame` misses
`setBounds:` and KVO of `bounds` misses `setFrame:` (true, each alone) and that an observer would fault when its view deallocated
(reasoned, not measured). The review (A1) asked for the union and the measurement; the union covers every waking path and the
lifetime is benign or avoidable as above, so the wrap is gone.

## M4. limitAttachment maximum length

Measured (host, `m_lim.m`; A at (100, 100), B at (300, 100), the rope read raw):

| case | `length` before add | maxLength after add | `length` after add |
|---|---|---|---|
| no move | 200 | 2 m | 200 |
| B moved to 300 before add | 200 | 3 m | 300 |
| B moved to 150 before add | 200 | 1.5 m | 150 |
| moved after add (with or without `updateItemUsingCurrentState:`) | 200 | 2 m | 200 |
| offsets (10, 0)/(0, 5), B moved to 300 | 200 | 3.10040307 m | 310.040314 |

Rule: the factory keeps the centres' distance (offsets ignored) as the `length` it answers until association; the rope is built
at association from the current bodies, anchors `c - o` (offsets negated, world axes, §6.4), `maxLength = |wB - wA|/ptm`, and is
not re-evaluated afterwards; `length` then answers `maxLength * ptm`.

## Minimum and placement

**Rule: the Dynamics classes carry no minimum of their own**: the owner's rule is that a minimum raised because a release lacks
some API is a refusal, allowed only for missing hardware, so Dynamics goes down to 4.3. The 7.0 classes are `implemented` with
no minimum; their 9.0 members `implemented` with `maximum` 7.0 (the release's class from 7.0 has no such members). What 4.3
lacks is looked up or carried: `UICollectionViewLayout` and its attributes (6.0) are found by name, Nil below 6.0 where nothing
can be one; `__weak` below 5.0 is charon's arclite; the tables use `+mapTableWithKeyOptions:valueOptions:` (the item behaviour's
velocity caches, keys not retained since `items` holds each item; the contact listener's opaque `b2Contact *` keys).

Measured (`objc.inventory` of the caches): `NSMapTable` on 4.3, 5.0 and 5.1.1 has `+mapTableWithKeyOptions:valueOptions:`,
`-objectForKey:`, `-setObject:forKey:`, `-removeObjectForKey:`, `-keyEnumerator`, `-count`, but **not
`+weakToStrongObjectsMapTable` or `+strongToStrongObjectsMapTable`**; 6.0 and 7.0 have both. `_OBJC_CLASS_$_NSMapTable` is
exported from 3.0, `_objc_storeWeak` from 5.0.

**Retracted**: "the Dynamics minimum is 6.0" (the band's commit registering the 7.0 classes as implemented from 6.0) was
withdrawn by the owner's rule; the minimum was removed.
