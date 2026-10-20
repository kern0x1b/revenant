# UIKit Dynamics, iOS 9.0: UIFieldBehavior, UIRegion, UIDynamicItemGroup and the 9.0 members

Introduced in iOS 9.0: `UIFieldBehavior`, `UIRegion`, `UIDynamicItemGroup`, and the optional `UIDynamicItem` members
`collisionBoundsType` and `collisionBoundingPath`. The 9.0 members of the 7.0 classes (`charge`, `anchored`, `snapPoint`,
`frictionTorque`, `attachmentRange`, the five attachment factories, `UIFloatRange`) are in `UIDynamicAnimator.md` (§2.10, §5,
§6.4), with the 7.0 rules this file builds on.

**Rule: the 9.0 classes are written once, over the public 7.0 API**: `UIDynamicBehavior` subclasses with child behaviours
and an action block, the field's force given each animator step through `-[UIDynamicItemBehavior addLinearVelocity:forItem:]`.
The same code runs over Apple's 7.0 classes on iOS 7.0-8.x and over the port's own below 7.0. For every member this file says
whether that is exact, approximate (with the measured difference against the host) or not expressible (with the measured
reason, the registry's `maximum`). Like the 7.0 classes they carry no minimum of their own (`UIDynamicAnimator.md`, Minimum
and placement): what 4.3 lacks is carried or replaced, e.g. `+strongToStrongObjectsMapTable` (6.0) by
`+mapTableWithKeyOptions:valueOptions:`.

Marks as in `UIDynamicAnimator.md`: **measured (host)** = the host's UIKitCore and PhysicsKit through Mac Catalyst (macOS
27.0), by the band's oracle probes (named by file, not in the tree); **read (host)** = the host's PhysicsKit and UIKitCore
disassembled. 100 pt per metre. The host sub-steps at (float)1/120 (`UIDynamicAnimator.md` §0). Section `§N` is the band's 9.0
specification's §N (it has no §11), `MN` its second measurement round's §N.

## §0. Step context the field rules depend on

Measured and read (host):
- The world steps in fixed sub-steps of 0.00833333377f s, then `ClearForces()`. **Fields are evaluated once per sub-step,
  inside `b2Island::Solve`**, not once per frame: measured, a drag field matches the per-sub-step model to 1e-6 m/s (v
  0.991667 -> 0.983472 -> 0.975412 predicted, 0.975411453 measured).
- One dynamic body in the island (read):

```
u = aether.evalVelocity(fieldBitMask, pos, v, m, q, t)
if (u.x < FLT_MAX) v = u;                         // inside a velocity field: forces, gravity and m_force ignored
else { F = aether.evalForce(fieldBitMask, affectedByGravity, pos, v, m, q, t); v += h * invMass * (F + m_force); }
w += h * invI * torque;  then damping 1/(1 + h*c) on v (the velocity-field result too) and w
```

  `evalForce` = world gravity * m (when affected) + the sum of the fields' forces, in newtons. UIKit never sets a field's
  `override` (measured `f_1`), so that path can be ignored.
- `t` = world time after this sub-step, **accumulated in double** from `(double)0.00833333377f` (first sub-step of a new world
  0.00833333377). The specification had said float-accumulated; M7 measured double (the two print alike at first and differ in
  the last bits, which noise amplifies).

## §10. UIFieldBehavior

### §10.1 Properties, defaults, mapping to PhysicsKit

Measured (host, `f_1`):

| factory | strength | falloff | direction | smoothness / animationSpeed |
|---|---|---|---|---|
| `dragField` | 1 | 0 | (0, 0) | 0 / 0 |
| `vortexField` | 1 | 0 | (0, 0) | 0 / 0 |
| `radialGravityFieldWithPosition:p` | 1 | **2** | (0, 0) | 0 / 0 |
| `linearGravityFieldWithVector:v` | 1 | 0 | v | 0 / 0 |
| `velocityFieldWithVector:v` | 1 | 0 | v | 0 / 0 |
| `noiseFieldWithSmoothness:s animationSpeed:a` | 1 | 0 | (0, 0) | s / a |
| `turbulenceFieldWithSmoothness:s animationSpeed:a` | 1 | 0 | (0, 0) | s / a |
| `springField` | 1 | **-1** | (0, 0) | 0 / 0 |
| `electricField`, `magneticField` | 1 | **1** | (0, 0) | 0 / 0 |
| `fieldWithEvaluationBlock:` | 1 | 0 | (0, 0) | 0 / 0 |

- `minimumRadius` 0.00305175781 for all (stored as float metres, default 2^-15 m, read back * 100). Position (0, 0) except the
  radial field's; stored as `(float)x * 0.01f` and answered `(double)stored * 100`, so (30, 40) reads back (29.9999982,
  39.9999976). Strength, falloff, direction (a CGVector, **not** scaled by ptm), smoothness and animation speed stored as float.
- Region default `+[UIRegion infiniteRegion]`, the same instance for every field; `items` empty.
- Only noise and turbulence keep smoothness and animation speed: on the others the getters answer 0 after a set (measured).
- The region is tested in the field's local space in points: `[region containsPoint:(bodyPosition - fieldPosition)]`
  (measured: a radius-50 region acts on a body at distance 50, not at 50.001). The evaluation point is the body's origin, the
  item's center.
- Accessors, read (host listings of the `UIFieldBehavior` and `PKPhysicsField` accessors): every setter rounds to float
  first (`fcvt`); `setPosition:` stores `(float)x * PKGet_INV_PTM_RATIO()` (float multiply) and `position` answers
  `(double)stored * (double)PKGet_PTM_RATIO()`; `setMinimumRadius:` stores `(float)r * INV` and `minimumRadius` answers
  `stored / INV` (a float divide, so 3 reads back 3); strength, falloff, direction, smoothness and animation speed are
  stored and answered as float, the last two only when `_fieldFlags.fieldIsKindOfNoiseField` is set. Each setter ends in
  `-_changedParameter`.
- **The ratio is PhysicsKit's global one**: measured (`p4.m`), `PKGet_PTM_RATIO` is SpriteKit's 150 until the process makes
  its first `UIDynamicAnimator`, which sets UIKit's 100 for good. A field or region made before any animator converts with
  150 (a region's half extent, a field's stored position), so its answers differ from the 100 ones in the last bits. The
  port always converts with 100; the host tests make an animator first.
- Measured (`p1.m`): `-init` raises an `NSException` named `Invalid initialization`, reason `Use one of the supplied
  convenience initializers`; `-addChildBehavior:` on a field is ignored (`childBehaviors` stays empty); the description is
  `<UIFieldBehavior: 0x...>`; neither NSCopying nor NSCoding.

### §10.2 Force formulas

Read (host evalForce of each kind), confirmed by the measured numbers (`f_2`, `f_3`). In PhysicsKit units: `p` = body position
minus field position in metres, `r = |p|`, `p^ = p/r`, `v` m/s, `m` kg, `q` charge, `S` strength, `k` falloff, `rmin` metres;
`fall(r) = |k| < 2^-15 ? 1 : powf(r < rmin ? rmin : r, -k)`. Each kind first answers 0 when `|S * X| < 2^-15`. The result is a
force; the island divides by mass.

| kind | force (N) | acceleration | X of the zero test |
|---|---|---|---|
| linear gravity | `S * m * d * fall(r)` | mass independent | m |
| radial gravity | `-S * m * p^ * fall(r)`, 0 if r^2 < 1e-5 | toward the position for S > 0 | m |
| electric | `S * q * p^ * fall(r)` (r = 0 gives NaN) | `/ m` | q |
| magnetic | `S * (v.y, -v.x) * fall(r)`: **charge is no factor** (q = 1 and -1 give the same force) | `/ m` | q |
| spring | `-S * p^ * fall(r)`, 0 if r < 1e-5; with k = -1 Hooke's `-S * p`, not mass-scaled | `/ m` | 1 |
| vortex | `S * (-p^.y, p^.x) * fall(r) / m`: **divided by the mass once more** | `/ m^2` | m |
| drag | `-S * u * |u| * fall(r)`, `u = v - direction` (the medium's velocity) | `/ m` | 1 |
| velocity | none: sets the velocity (§10.3) | | |
| noise, turbulence | M7 | | 1 |
| custom block | the block's vector as the force, **not times strength**, no falloff | `/ m` | 1 (S = 0 disables) |

Measured (steady 1/60 frames, 100x100 item at (300, 400), so p = (3, 4) m, r = 5, m = 1, resistance 0): linear (3, 4): a = (300,
400) pt/s^2 for m = 1, 2, 3; S 2, k 1: (120, 160). Radial at the origin, k 2: -(2.4, 3.2), the same for m = 3; S 2, k 1, rmin 1000
pt: -(12, 16) (clamped at 10 m). Electric q 2: (24, 32), m 3: (8, 10.667), q 0: none. Magnetic, v (100, 0) pt/s, k 1: (0, -20)
for q = 2, 1, -1 alike; m 3: (0, -6.667). Spring: -(300, 400), m 3: -(100, 133.3). Vortex: (-80, 60), m 3: (-8.889, 6.667);
S 2, k 1, rmin 10 m: (-16, 12). Drag from v0 (100, 0): 97.5411453 pt/s after frame 1 exactly; direction (1, 0) with v (1, 0) m/s:
none. Block returning (1, 0): 100 pt/s^2; m 3 with S 2: 33.33.

Operation order, read (host `PKCField<Kind>::evalForce`, `PKCField::calculatedFalloff`; E is the field's scale factor at
+0xc0, 1 in UIKit): the zero tests are `|m*(S*E)|` (linear, radial, vortex), `|q*(S*E)|` (electric, magnetic), `|S*E|`
(the others), each `< 2^-15`; `d = p + (-f)`, `r = sqrtf(0 + (d.x*d.x + d.y*d.y))`, no fused operation. Linear `((dir*(S*E))*m)
* fall`; radial and spring return 0 below `r^2 < 1e-5f` and `r < 1e-5f` respectively (constant 0x3727c5ac), then `(d/r) *
((-(m*S))*E * fall)` and `(d/r) * (-(S*E) * fall)`; electric `(d/r) * ((q*(S*E)) * fall)`; magnetic the cross product
`v x (0, 0, 1)` times `(S*E) * fall`; vortex `((d.y/r, -d.x/r) * (-(S*E) * fall)) / m` (constants (1, -0, -0, 0) and
(0, 0, -1, 0)); drag `u = v - dir`, 0 when `|u| <= 2^-15`, else `((u*|u|)*(-S))*E * fall`; turbulence `((F*m)*|v|)*|v|`
on the noise force. Custom (`PKCFieldUser`, measured `p3.m`): the block gets the position in field-local points, the
velocity in m/s, the mass in kg, the charge and the world time after the sub-step, and its vector is the force.

**Apple's quirks, copied**: magnetic ignores the sign and size of the charge; vortex divides by the mass twice; spring,
electric, magnetic, drag, noise and block forces are not mass-scaled (a heavier item accelerates less), linear, radial and
vortex are.

### §10.3 Velocity field

Measured (host, `f_2`, `f_3`): while the body is in the region its velocity is **replaced** by `direction` m/s (`direction *
100` pt/s) every sub-step; strength, falloff and minimum radius are ignored; gravity, other fields and forces do nothing to it
in that sub-step; linear damping still applies after (resistance 0.1: 3000 / (1 + h * 0.1) = 2997.50195 pt/s). Only the first
velocity field containing the body counts. (30, 40): v = (3000, 4000) pt/s after the first frame whatever it was before.

### §10.4 Items, categories, where forces apply

Measured (host, `f_4`):
- Each field added to an animator takes the highest free of 32 indexes and the category `1 << index` (first 0x80000000, then
  0x40000000); removal gives it back. A 33rd raises (M5).
- An item's field mask is the OR of the categories of the fields whose `items` hold it: **a field acts only on its own items**,
  and an item in several fields gets the sum (A (1, 0) + B (0, 2) -> (0.8333, 1.6667) pt/s after one sub-step).
- An item only in a field still gets a body (not affected by gravity, resistance 0.1) and moves; items added later are picked
  up at the next step. An anchored item is not moved.
- Forces enter inside the island before the velocity solver of each sub-step, not through `ApplyForce`.

### §10.5 Noise and turbulence

The specification left the product after the falloff unknown; M7 measured it bit-exactly.

### §10.6 UIRegion

Measured (host, `s_reg.m`); **exact on every release** (a value class, no animator):
- `initWithRadius:R`: `x*x + y*y <= R*R` (inclusive; a negative radius acts as |R|).
- `initWithSize:(w, h)`, centred: `|x| < w/2 && |y| < h/2` (strict: (50, 0), (0, 25) and the corner are outside 100x50);
  negative sizes contain nothing.
- `+infiniteRegion`: one shared instance (measured, same pointer), contains everything; its inverse nothing.
- `inverseRegion`: measured (`p1.m`), the inverse of the 100x50 rectangle **contains** its edge point (50, 0): the inverse is
  the plain complement `!(|x| < w/2 && |y| < h/2)`, and the edge is outside the rectangle and inside its inverse. (The
  specification had read "in neither" from the intersection row; that row comes from the intersection's own test below.)
- Read (host `-[PKRegion containsPoint:]`, the three operations, `-inverseRegion`): a PKRegion is not a tree. It is one
  primitive shape with an inversion flag, plus at most one second shape and the operation joining them: an operation
  copies the receiver and puts the other region's primitive into the second slot, replacing what was there and dropping the
  other's own second shape; the inversion flag belongs to the first shape. Union with an inverted region becomes a
  difference and difference from one a union; intersection ignores the other's inversion and tests it as "not outside", so
  it takes a rectangle's edge in. A region made with `-init` holds no PKRegion and contains nothing; the host dereferences
  a nil or `-init` operand unchecked (a bad access), which the port refuses with `NSInvalidArgumentException`.
- Union `a || b`; difference `a && !b`; **intersection `a && !inverse(b)`** (measured: circle 50 intersected with rect 100x50
  contains (50, 0) and (0, 25), which the rect alone excludes).
- NSCopying (a new object) and NSCoding.

### §10.7 Field emulation over the public 7.0 API

The design, one code path: `UIFieldBehavior : UIDynamicBehavior`, a composite owning a child `UIDynamicItemBehavior` carrier
that holds the field's items (none of its properties set, so it pushes nothing to the bodies, `UIDynamicAnimator.md` §2.5), and
an action run once per animator step, after the world step:

```
dt = animator.elapsedTime - last; last = animator.elapsedTime;
for (item in carrier.items) {
    P = item.center (a view: converted to the reference view); v = [carrier linearVelocityForItem:item];
    if (![region containsPoint:(P - position)]) continue;
    velocity field: [carrier addLinearVelocity:(direction * 100 - v) forItem:item];
    else: a = force(kind, (P - position)/100, v/100, m, q, t) / m * 100; [carrier addLinearVelocity:(a * dt) forItem:item];
}
```

- Mass: not public on 7.0-8.x: `density * width * height / 100^2`, with the density of the last item behaviour in traversal
  order holding the item whose density is not 1, else 1 (an approximation of the flag rule; exact when one behaviour sets it;
  error not measured for density != 1). Below 7.0 the port's animator can give the body's mass.
- Charge: 0 on 7.0-8.x (no such property), so electric and magnetic fields do nothing there, exactly as Apple's would with
  charge 0. Below 7.0 the port's body's charge.
- Anchored items: below 7.0 only (the port's class): skipped.
- The 32-field limit: counted per animator; the 33rd raises the host's exception (M5).
- **Measured error** against Apple's 9.0 field (host, `s_fld.m`; 100x100 at (300, 400), mass 1, resistance 0, 60 frames): the
  one-step lag of a velocity given by an action, and per-step instead of per-sub-step evaluation:

| field | Apple f60 | emulation f60 | max error, 10 frames | max error, 60 frames |
|---|---|---|---|---|
| linear gravity (3, 4) | (448.7500, 598.3333) | (447.5000, 596.6667) | 0.3472 | 2.083 (0.84 % of the travel) |
| radial gravity S 200 at (0, 0) | (-1673.68, -2231.57) | (-487.89, -650.53) | 0.5644 | 1976 (passes the singularity) |
| spring S 4 at (250, 350) | (229.5706, 329.5706) | (229.9463, 329.9463) | 0.1927 | 0.5855 |
| vortex S 2 at (250, 350) | (218.9498, 451.9500) | (219.6843, 451.6683) | 0.139 | 0.7867 |
| drag S 0.5, v0 100 pt/s | (380.3465, 400) | (380.4333, 400) | 0.02991 | 0.08682 |
| velocity (1, -0.5) | (399.1680, 350.4174) | (398.3347, 350.8341) | 0.9317 | 0.9317 (one frame of travel) |

  Electric and magnetic: exact (vacuously) on 7.0-8.x, approximate below 7.0; noise, turbulence, custom block: approximate, the
  same lag. **Registry `maximum` of every field kind: "approximate: applied once per animator step after the world step (a
  one-step lag), not per Box2D sub-step"**, with these numbers; radial gravity only away from its centre.
- Apple's velocity field also switches gravity off for its items; the emulation cannot switch world gravity off for one body,
  so a velocity-field item in a gravity behaviour gains g * dt in each step before the next correction (16.7 pt/s at 1 g, 60 Hz).
  Only the first velocity field holding a body counts on the host; in the emulation each acts in turn, so the last one wins.
- The port's realisation (`UIKit/UIFieldBehavior.m`): the action is the carrier's, not the field's own (an application's
  `action` on the field stays its own); the carrier becomes the field's child in `willMoveToAnimator:` once the count lets
  the field in, and leaves in `willMoveToAnimator:nil`, so a refused field holds nothing registered; `childBehaviors` answers
  an empty array as the host's. The clock handed to noise and to a block is `animator.elapsedTime` after the step. A
  parameter change does not wake a paused animator (the 7.0 API has no call that only wakes one; while a field acts its
  items do not rest).
- Measured (the port against the host, `tests/backports/host/dynamics/fields_test.m` F4): the port's emulation over its own
  7.0 classes lands at frame 60 on s_fld's "emulation f60" column to the 4 decimals printed, in every row above, and its
  worst distance from Apple's field over the frames equals the table's maximum error.

## §12. UIDynamicItemGroup

### §12.1 The object, outside an animator

Measured (host, `g_group1.m`, `g_conf.m`, `g_conf2.m`), read (host); **exact on every release** (a plain
`NSObject <UIDynamicItem>`):
- `-initWithItems:`: a table item -> offset (strong keys and values); an empty array stops there (center (0, 0)). Else
  `_center` = **the middle of the union rect** of the items (not a centroid, not mass-weighted), then for each item: a group
  among them raises `[NSException raise:@"Invalid Argument" format:@"%@ cannot be initialized with items containing %@", ...]`
  (measured reason `UIDynamicItemGroup cannot be initialized with items containing UIDynamicItemGroup`; the name is literally
  `Invalid Argument`), else offset = `item.center - _center`. A duplicate item raises nothing (one key).
- The union rect: each item's `(center - size/2, size)` from `bounds.size`, item transforms ignored (measured: a member rotated
  pi/2 with bounds 100x20 counts as 100x20).
- **`_transform` is not initialised**: a fresh group answers the all-zero matrix (measured `[0 0 0 0 0 0]`; the animator reads
  angle `atan2(0, 0) = 0`). Reproduced.
- `-bounds` = `(0, 0, union of the current members' size)`, recomputed on every call (measured 180.774772 x 124.122519 after
  rotation 0.3 of 100x100 + 50x20); empty group `(0, 0, 0, 0)`.
- `-items`: the table's keys (init order seen for two; do not rely on it). `-center`: the stored one, not recomputed.
- `-setCenter:c`: `d = c - _center`; every member's center moves by d; `_center = c` (a member moved by hand keeps its
  displacement).
- `-setTransform:t`: an equal transform writes nothing. Else every member's center becomes `_center + t applied to its init
  offset` (with tx, ty) and its transform t, its own discarded. Measured: A 100x100 at (100, 100), B 50x20 at (220, 130), center
  set to (157.5, 105), t = rotation 0.3 with tx 7: A (119.121517, 90.9627902), B (224.896289, 155.08531); identity afterwards puts
  members back at `_center + offset` exactly.
- The group does not implement `collisionBoundsType` or `collisionBoundingPath` (measured).

### §12.2 Apple's compound body

Read (host `_registerBodyForItem`, `_newBodyForItem:inItemGroup:`, `-[PKPhysicsBody initWithBodies:]`), measured (`g_group1.m`,
`g_rot.m`):
- The size check comes first for every item: an empty group fails `Invalid size {0, 0} for item <UIDynamicItemGroup: ...> in
  Dynamics` (`NSInternalInconsistencyException`) at `addBehavior:`.
- A group is **one b2Body at the group's center with one fixture per member**, each shape at the member's offset from the group
  center (current centers at registration), axis-aligned whatever the member's transform. Mass = density * the sum of the
  member areas (measured 1.09999999 for 100x100 + 50x20). An item behaviour on the group sets every fixture (density 3 -> mass
  3.29999998); on a member it makes a second, separate body for it. Members have no body of their own.

### §12.3 Apple's write-back

Measured (`g_rot.m`): the group body is written back rounded like a view (`UIDynamicAnimator.md` §2.8: body y 100.069389,
100.416092 -> group y 100, 100.5 at scale 2; angles multiples of 1/5000) through `setCenter:` and `setTransform:`, which write
the members, unrounded. The first step always writes the transform: the fresh zero matrix differs from `MakeRotation(0)`.

### §12.4 Conflicts

Measured (`g_conf.m`, `g_conf2.m`), no exception in any: a member added directly to another behaviour gets its own body too,
both write the item (order unspecified); an item in two groups gets both groups' center deltas added, the last transform
wins; a group in two behaviours shares one body.

### §12.5 Over the public 7.0 API

- The object (§12.1): exact.
- In an animator of 7.0-8.x, and in the port's, the group is an ordinary item: **one rectangle of `group.bounds.size` at
  `group.center`**, mass = density * the union area, a plain object so not rounded. The empty group fails the same size
  assertion (7.0 has it): exact.
- Measured (`s_grp.m`, the two members under gravity onto a sloped boundary (0, 300)-(400, 330), 120 frames): free fall differs
  by rounding only (member B at f20: Apple (220, 183.5), box (220, 183.5551), max 0.2068 pt over 20 frames); after the first
  contact they diverge (more than 0.5 pt from frame 34; f120 B Apple (251.0624, 296.8200, 0.0746), box (220.1598, 294.7867,
  0.0733), max 30.97 pt).
- **Registry `maximum`: approximate, "the compound collision shape is not carried below 7.0 (deferred: the port's own animator
  can build it); not expressible on 7.0-8.x, whose animator builds exactly one rectangle per item; measured 31 pt divergence
  after contact, 0.21 pt in free fall".**
- Measured (the port against the host, `group_test.m` G3): over 20 frames of free fall member B of the port's group stays
  within 1e-3 pt of the host driving a plain item of the union box, and within 0.21 pt of the host's own group.

## §13. collisionBoundsType and collisionBoundingPath

Measured (host, `g_cb1.m`):
- Not implemented by UIView, UICollectionViewLayoutAttributes (6.1.3, 7.0, 8.4.1, 9.0) or the group; read only when the item
  responds; otherwise Rectangle.
- Ellipse: equal sides make a circle of radius w/2; otherwise one convex polygon (M6), radius 0.00899999961 m; `bounds.origin`
  ignored.
- Path: in item-local points, the first subpath only, curves flattened, one convex polygon, radius 0.009 m; a concave path is
  accepted with inertia 0 (a host bug, not copied beyond "accepted"). `NSInvalidArgumentException` at `addBehavior:` for a nil,
  empty, 2-point, collinear or self-intersecting path: `UIDynamicItem (%@) provided an invalid bounding path`; for Path without
  the method: `UIDynamicItem (%@) MUST implement -[UIDynamicItem boundingPath] when specifying a collision bounds of
  UIDynamicItemCollisionBoundsPath` (the selector name wrong in the original). An out-of-range type crashes the host in
  `-[__NSArrayM insertObject:atIndex:]`: not copied.
- **Not carried below 7.0 (deferred); not expressible over the public 7.0 API on 7.0-8.x** (registry `maximum`): read (7.0), `_registerBodyForItem:shape:` never sends
  `collisionBoundsType`, so every item gets its bounds rectangle; the only shape switch is the private
  `_setUseCircularBoundingBox:`, which is private API and not used.
- Were the port's own animator to honour them below 7.0: a circle shape, and for a polygon of more than 2.2.1's 8 vertices a
  fan of convex pieces sharing vertex 0, one fixture each, radius 0.009f (mass additive; contacts at the seams may differ, not
  measured).

## §14. Expressibility summary

| 9.0 member or class | 7.0-8.x (Apple's classes) | below 7.0 (the port's) | why |
|---|---|---|---|
| UIRegion | exact | exact | §10.6 |
| field properties, factories, items, region, the 32-field limit | exact | exact | §10.1, §10.4, M5 |
| linear, radial, spring, vortex, drag, velocity, custom forces | approximate | approximate | §10.7: 0.09 to 2.1 pt over 60 frames |
| electric, magnetic | exact (charge 0) | approximate | §10.7 |
| noise, turbulence | approximate | approximate | the force exact, the trajectory lagged (M7) |
| UIDynamicItemGroup object | exact | exact | §12.1 |
| UIDynamicItemGroup in an animator | approximate (not expressible) | approximate (deferred: §12.2's compound body) | §12.5 |
| collisionBoundsType Ellipse, Path | not expressible | not carried yet (deferred: §13's circle and fan of convex pieces) | §13 |
| 9.0 members of the 7.0 classes | absent (Apple's class) | exact | `UIDynamicAnimator.md` §2.10, §5, §6.4 |

## §15. Implementation rules

- `UIRegion : NSObject <NSCopying, NSSecureCoding>`: kind (circle, rect, infinite, union, difference, intersection, inverse),
  radius or size, operands; `+infiniteRegion` a singleton.
- `UIFieldBehavior : UIDynamicBehavior`: kind, position, region (default the infinite one), strength 1, falloff per kind
  (§10.1), minimum radius stored as float metres, direction, smoothness and animation speed for the noise kinds, the block, the
  carrier child, the last elapsed time; `addItem:`, `removeItem:`, `items` go to the carrier; `willMoveToAnimator:` counts the
  fields and resets the elapsed time; the action of §10.7 with the formulas of §10.2 and their quirks.
- `UIDynamicItemGroup : NSObject <UIDynamicItem>`: §12.1 exactly, with a table built by what 4.3 has.
- Nothing for collision bounds (§13). `UIFloatRangeZero` and `UIFloatRangeInfinite` are exported with the attachment
  (`UIDynamicAnimator.md` §6.4).

## §16. Host test plan

In `tests/backports/host/dynamics`, beside the 7.0 rows (`UIDynamicAnimator.md` §12), each with a negative control in
`mutants.sh`:

| row | scene | oracle numbers | tolerance |
|---|---|---|---|
| F1 | defaults per factory, minimum radius 0.00305175781, position round trip 29.9999982 | §10.1 | exact |
| F2 | UIRegion truth table (8 points x 7 regions), negative radius and size | §10.6 | exact |
| F3 | the 33rd field's exception name and reason | M5 | exact |
| F4 | emulated trajectories against Apple's field | §10.7 table, f60 | 1.2 x the measured maximum per row; radial only beyond 50 pt |
| F5 | the force formulas' accelerations | §10.2 numbers | 1e-3 relative, of the emulation's acceleration function |
| G1 | group center, bounds and transform algebra | §12.1 | 1e-9 |
| G2 | `Invalid Argument` group in a group, the empty group's size assertion | §12.1, §12.5 | exact |
| G3 | a group in an animator: member B at f20 (220, 183.5551) with the box body | §12.5 | 1e-3 pt; against Apple's compound the documented 0.21 pt |

## §17. Open

- A rectangle region's inverse on its exact edge: settled, measured (`p1.m`, §10.6): the inverse contains it.
- The mass the emulation uses on 7.0-8.x is approximate (§10.7), its error for density != 1 not measured.
- The per-step trajectory error of noise and turbulence is not measured (M7).
- **Deferred below 7.0** (the port's own animator, not Apple's, so nothing here is a wall): the compound body of an
  `UIDynamicItemGroup` (§12.2: one fixture per member) and the `collisionBoundsType` Ellipse and Path bounds (§13: a circle
  shape, a fan of convex pieces). Until they are built the group is one rectangle and an Ellipse or Path item keeps its
  bounds rectangle; on 7.0-8.x they stay not expressible.
- Noise's factor after the falloff: settled by M7. The ellipse's vertex count: settled by M6. Whether Apple leaves a 33rd
  field registered: settled by M5 (it does not).

## M5. The 33rd UIFieldBehavior

Measured (host, `m_f33.m`: a 10x10 item in 32 linear fields (1, 0) and a 33rd (0, 1)); call order read in the host's
`_registerBehavior:`:
- Control: 32 fields give (26.6666679, 0) pt/s after the first step (32 x 0.8333), (53.3333359, 0) after later ones.
- The 33rd `addBehavior:` raises an NSException named **`Invalid Association`**, reason **`UIDynamicAnimator supports a maximum
  of 32 distinct fields`**, from `_registerFieldCategoryForFieldBehavior:` inside `_registerBehavior:`, **before
  `_setContext:`**, `willMoveToAnimator:` and `_associate`. After it: the field is in `animator.behaviors` (added to the
  top-level list first), not registered, `dynamicAnimator` nil, no force. `removeBehavior:` of it raises nothing. Once a field
  is removed, adding it again works (category 0x80000000).
- As a child of a composite added later: the same exception out of the parent's association; the parent is left in
  `behaviors`, context set, unregistered, the field still queued; removing the parent queues it again, so a later add raises
  `Adding the same behavior twice ...`. Via `addChildBehavior:` of a registered composite: the same exception, the field not
  among the children.
- Over Apple's 7.0-8.x animator the port can only count in `willMoveToAnimator:`, which runs after Apple's `_setContext:`: so
  there, after the raise, `dynamicAnimator` answers the animator and the field is half-registered. Only the port's own animator
  (below 7.0) can check before `_setContext:`.

## M6. Ellipse collision bounds polygon

Measured (host, `m_ell.m`): every ordered pair w != h of {2, 10, 20, ..., 1000}, 182 ellipses; the algorithm below reproduces
**all 182 vertex lists bit-exactly** (count and every float). Counts, e.g. 20x10 4, 100x50 24, 60x200 44, 1000x500 244; radius
0.00899999961. **The host fork has no 8-vertex limit** (up to 244; stock 2.2.1 has 8).

```
path = CGPathCreateWithEllipseInRect((-w/2, -h/2, w, h)): moveTo (w/2, 0), 4 cubics (kappa 0.55228474983), close
flatten, in float points: first moveTo pushed, a later one stops; lineTo pushed; close pushes the first point and stops;
  cubic (p0 = last pushed): L = 0; prev = p0;
    for i in 0..10: q = B(prev, p1, p2, p3, (float)i/10); L += sqrtf(fmaf(dx, dx, dy*dy)); prev = q;   // the start is the
    count = max((int)(L / 10.0f), 1);                                                                 // previous sample
    for i in 0..count: push B(p0, p1, p2, p3, (float)((double)i/count))
  B: t clamped to [0, 1]; u = 1 - t; ((p0*u*(u*u) + p1*t*(u*(u*3))) + p2*t*(t*(u*3))) + p3*t*(t*t), float, no FMA
to metres (* 0.01f); drop a vertex within fmaf-squared 1.42108547e-14 of the last kept; drop trailing ones equal to the first
while 3 remain; fewer than 3: no body; reverse if the first turn is clockwise; b2PolygonShape radius 0.009f
```

A plain "length of the 10-segment polyline" estimate matches only 160 of 182 counts: the chained start is the host's quirk.
7.0's boundary path applier has the same chained estimate (read), so `UIDynamicAnimator.md` §7.4's curve flattening follows this
step too.

## M7. Noise and turbulence field force

Measured (host, `m_noise2.m`: PhysicsKit's own `evalForce` called directly against the candidate over 1000 random fields x 60
points, and end to end through `_animatorStep:`): **noise 60000/60000 and turbulence 60000/60000 bit-exact**, the falloff
60000/60000, Gustavson's `srdnoise3` 200000 samples exact, end to end 200/200 sub-steps in all 4 runs. Formula (read in the
host listing, confirmed by the match), float except `t`:

```
if (fabsf(S) < 2^-15) return 0;                          // strict: |S| = 2^-15 still acts
T  = (float)(t * (double)animationSpeed);
l  = (p.x + T - f.x, p.y + T - f.y, T);                   // time shifts all three coordinates; f the field position
fr = 1.25f / (fmaxf(smoothness, 0) + 0.0833333358f) - 1;   // smoothness <= 0 -> 14
(s, c) = sincosf(T);                                       // the gradient's rotation angle is T
n  = srdnoise3_sincos(fr*l.x, fr*l.y, fr*l.z, s, c, &g);  // Gustavson's simplex noise with rotating gradients
F  = ((g * fall(p)) * n) * S;                              // fall of the unshifted p (§10.2); n multiplies the gradient
turbulence: F * m * |v| * |v|  (((F * m) * sp) * sp)
```

- `srdnoise3`: F3 0.333333343f, G3 0.166666672f, radius 0.6f, scale 28, the host's permutation and gradient tables (read
  from its memory, `m_srd_tables.txt`: Gustavson's published `grad3u`/`grad3v` and Ken Perlin's permutation twice), index
  `(i + 512) % 256` with C's remainder, so for i < -512 it reads the bytes just before the permutation table (the host's layout:
  gradients v at -0xc0, u at -0x180). Its float expressions are fused as clang fuses them on arm64 (58 fused operations).
- The clock: `t` in double after the sub-step (§0). Negative controls, measured: a float clock 16-71/200 exact, the time before
  the sub-step 0/200, gradient angle 0 instead of T 0/36585, strength below 2^-15 exactly 0 on both.
- Mass: noise ignores it (dv = h * F / m); turbulence multiplies by m. Only F.x and F.y act.
- The 58 fused operations, read (host listing of `srdnoise3_sincos`): per corner `t = fma(-z, z, fma(-y, y, fma(-x, x,
  0.6)))`, each gradient component `fma(cos, u, sin * v)`, the dot product `fma(gz, z, fma(gx, x, gy * y))`; in the
  derivative the corner-0 term is plain, corners 1-3 add `fma(temp, x, d)`, and the last sum is
  `fma(t4_3, g3, fma(t4_2, g2, fma(t4_0, g0, g1 * t4_1))) + d`. Nothing else is fused.
- **Built without FMA contraction** (`-ffp-contract=off`, what armv7's Cortex-A9 without fused multiply-add gets): noise 15293
  and turbulence 16559 of 60000 bit-exact, max relative error 6.67e-4 per evaluation. So the port writes the fused sites as
  explicit `fmaf()` to stay exact on armv7 (reasoned: the same operations; not run on a device).
- The force function is exact; the trajectory stays approximate for the per-step reason of §10.7, its error not measured.
