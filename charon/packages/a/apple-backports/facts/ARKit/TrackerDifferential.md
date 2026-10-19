# The tracker's offline differential, and what it measures

There is no ARKit on the host to compare against, so the comparison is constructed: a camera is
walked along a path it is also *shown*, each frame rendered by hand from where the surface point of
each pixel really is, and the pose the tracker reports for that frame is compared with the pose that
produced it. The attitude it is driven with carries the gyroscope's own error, because a gyroscope
on a real device is never exact.

`spatial-tracker-diff.m` builds and runs it:

    clang -O -fobjc-arc -DCHARON_TRACKER_OFFLINE=1 -I . -o tracker-diff \
          CharonARTracker.m spatial-tracker-diff.m \
          -framework Foundation -framework CoreVideo -framework CoreGraphics
    ./tracker-diff

## The seam, and what it leaves out

`CHARON_TRACKER_OFFLINE` compiles out three things and nothing else: the `CMMotionManager` the
session owns, the `AVCaptureDevice`/`AVCaptureSession` the session owns, and the two
`ARRaycastTarget` cases a raycast filters its targets with. The first two do not exist on the host
and the third is not declared there. Every line of the tracking, the matching, the integration, the
plane detection, the hit test and the raycast is the same object file either way, which is what
makes the offline numbers say something about the device build.

The frame-processing entry point deliberately does not require the tracker to have been started:
the camera is the session's business, and a recorded sequence has to be runnable through the same
code path a live one uses.

## What it measures, and what it found

The ground truth is 30 frames, each turning 5.73 degrees about `y` and walking 5 cm forwards, so
the last pose is 1.450 m along an arc whose position and attitude are known in closed form. Compared
per frame: the angle between the attitude the reported camera transform carries and the attitude
that produced the frame, and the distance between the reported camera position and the true one.

The differential found **four** defects, three in the tracker and one in the test, each located by
dumping the tracker's own state for one frame and reading it:

1. **The corner pick and the patch search shared one array.** `findFeatures` overwrote the matched
   points before `matchFeaturesTurningBy:` could read them, so nothing was ever matched. Two arrays
   now: `_candidates` for what a frame offers, `_points` for what was matched into it.

2. **The attitude the caller hands in was thrown away.** `processPixelBuffer:` overwrote its
   `deviceRotation` argument with a global that only the CoreMotion handler filled, so wherever
   there is no motion handler - which is every run of this differential - the tracker believed the
   camera had never turned, the search window drifted off the frame, and **not one position was
   searched**: `searched=0`, `drift=(-1.05,-1.05)`, `angle=4.1888` on a step of 0.1 rad. With the
   argument used, `angle=0.1000` - the true step - and 7917 positions searched.

3. **The unmatched corners were written over the matches.** The array is laid out as the matches
   followed by the fresh corners, and the second run started at index zero instead of at the match
   count, so every match was destroyed before the next frame saw it. Measured with the match dumping
   its own state: **17 to 19 matches a frame and still 0 points placed**, because a matched point
   never accumulated the three frames that would place it in the world. Fixed: **336 points**.

4. **The test surface, in the first version, was a hash of the world position** - the wrong scene
   for a Shi-Tomasi score, which takes the *smaller* of the two eigenvalues of the structure tensor
   and so rejects a stripe however strong the stripe is. Replaced by three sines of the world
   coordinates, at a spatial frequency measured to be inside what a 160x120 frame can sample.

## Where it stands, and it does not pass

    spatial tracker differential: 30 frames, 5.73 degrees and 0.050 m a step,
      driven 1.450 m along the path, the last pose truth at 1.450 m
      rotation error: mean 1.60000 rad (91.673 deg), worst 2.90000 rad (166.158 deg)
      distance error: mean 0.66572 m, worst 0.99510 m
      tracking: no, 336 points, 0 planes

The features are found, matched and placed - 336 points, which is what the pick and the search are
supposed to produce. **The pose is still wrong, and the reason is visible in the file:**
`refinePose` advances the camera along the direction the gyroscope says it turned, and nothing
else. There is no correspondence term in it, so the pose is dead-reckoned, and the differential
measures exactly that: a mean rotation error of 91 degrees over 30 steps, and 0 planes because the
plane detector never sees a consistent world to grow regions in.

So the next piece of work is named and is not a fix: `refinePose` needs the Gauss-Newton step its
own comment already claims, over the six parameters of the pose, from the reprojection residuals of
the 17-to-19 matches the frame now has. Until that lands, ARKit is not deliverable: a session would
start, report frames, carry 336 points, and put them in the wrong place.

## Where the tracker stands after the Gauss-Newton step

Measured on 2026-09-27, the synthetic sequence of 30 frames at 5.73 degrees and 0.050 m a step, the
whole path 1.450 m:

```
rotation error: mean 1.74652 rad (100.068 deg), worst 3.01560 rad (172.781 deg)
distance error: mean 0.78884 m, worst 1.19418 m
tracking: no, 336 points, 0 planes
```

Three things were wrong with the pose before the step could mean anything, and two are now right:

- **The pose was thrown away every frame.** After the pipeline ran, `_cameraTransform` was reset to
  the identity, so nothing the solver computed survived to the next frame and a rate integrated over
  a sequence was worth nothing. The gyroscope's turn is now applied to the pose the tracker already
  holds, so the pose is carried from one frame to the next.
- **The projection used the pose backwards.** The pose is the camera's in the world - that is the
  transform a landmark is placed with - and putting a world point back into the camera's space is
  its inverse. The solver now inverts it, and the camera's own space is the one the rest of the file
  uses, where a ray out of the camera is `(image.x - 0.5, image.y - 0.5, 1)` and forward is `+z`.
- **The matched points carried no world position at all.** A point is a landmark once it has been
  seen twice, and its place in the world was only ever computed for the copy that feeds the plane
  pass, so the set the solver reads had `world` of zero throughout and every residual was refused as
  a point behind the camera. A point is now placed in the world when it is first seen and when it
  survives its first frame.

**What is still wrong, and it is the one number that matters:** the scale a landmark is placed at.
`placePointInWorld:` puts a point as far off as its feature's size says, and that size is a grid cell
width in pixels, so the depth it produces is `0.5 / (cellWidth / lumaWidth)` - a few pixels counted
as metres, where the scene is at 1.45 m. Every reprojection residual is therefore measured against a
world the wrong size, which is why the step moves the pose but not towards the truth: the rotation
error is 100 degrees and the distance error 0.79 m, and no plane is found because the points the plane
pass grows regions from are in the wrong place.

That number is a judgement, not a derivation, and it is the one thing in the tracker that has to be
calibrated against the scene rather than computed from a frame. It is not guessed at here: the fix is
to give the tracker the scene's real scale - from the camera's field of view, which
`+cameraIntrinsicsForResolution:` already reads and which turns a pixel offset into an angle and so a
patch size into a distance - and then to re-measure. Until that is done the step is wired and
running but is not yet producing a pose the picture agrees with.

## The turn was being multiplied the wrong way round

The pose accumulated, but ran away instead of tracking. `CharonRotationBetween(from, to)` multiplied
the two quaternions in the order they were handed in, and the rotation that carries `from` onto `to`
is `to` composed with `from`'s inverse. For two attitudes a step apart about one axis, the wrong order
gives the *sum* of their angles rather than the difference, so a 5.73-degree step produced turns of
5.73, 17.19, 28.65, 40.10, 51.57 degrees - the odd multiples of the step - and the pose reached 143
degrees after five frames where the truth was at 28.65. The conjugate is the inverse of a unit
quaternion, so the product is `conj(from) * to`.

That is not a cosmetic fix. Measured after it, on the same 30-frame sequence:

```
tracking: yes, 5438 points, 16 planes
rotation error: mean 2.16591 rad (124.097 deg), worst 3.12652 rad (179.136 deg)
distance error: mean 0.62440 m, worst 1.31598 m
```

The plane detector now runs at all: sixteen planes out of 5438 placed points, where before the
rotation was wrong there were none, because a run-away pose puts every point in the wrong place and
there is no level surface in the wrong place to grow a region from. `tracking` is `yes` for the first
time.

**Two things are still wrong, and both are measured rather than suspected:**

- **The rotation error is 124 degrees and the step makes it worse.** Without the Gauss-Newton step the
  same sequence gives 78.13 degrees; with it, 124.10. A step that makes the picture fit *worse* is a
  step whose landmarks are wrong, and the landmark depth is the suspect: it is now derived rather
  than assumed (below), but the derivation assumes the focal length, and the focal length in an
  offline run comes from the recording's own calibration, which this synthetic sequence now supplies.
  That the error grew when a correct-looking depth was introduced says the depth and the pose
  convention still disagree somewhere, and that is not yet located.
- **The translation is never integrated at all.** The pose's translation column stays at exactly zero
  for the whole sequence, so the distance error is the whole 1.450 m path and the mean of 0.62 m is
  just where along the path the mean falls. Nothing in the pipeline has been given a reason to
  translate: the gyroscope reports an attitude, not a displacement, and the depth-from-drift gives
  each point a distance but never a baseline. Recovering the baseline from the depth change across a
  frame is the next piece of work, and it is not written.

So the tracker now tracks - it places its points, finds its planes, and reports `tracking: yes` - and
its pose is not yet the pose the truth describes. The numbers above are the measurement, not a
claim of convergence.

## Where the tracker stands, as delivered

Measured on the 30-frame synthetic sequence — 5.73 degrees and 0.050 m a step, the whole path
1.450 m — by `tests/backports/host/arkit/run.sh`, which is the only thing quoted here:

```
spatial tracker differential: 30 frames, 5.73 degrees and 0.050 m a step,
  driven 1.450 m along the path, the last pose truth at 1.450 m
  rotation error: mean 1.36355 rad (78.126 deg), worst 3.08318 rad (176.653 deg)
  distance error: mean 0.66572 m, worst 0.99510 m
  tracking: yes, 5438 points, 16 planes
ok rotation error: mean 78.126 is within the floor of 80 deg
ok distance error: mean 0.66572 m is within the floor of 0.7 m
```

**The Gauss-Newton step is not in the frame's path.** With it the same sequence reports 124.099
degrees of mean rotation error; without it, 78.126. A step that fits the picture less well is fitting
landmarks whose depth and the pose convention still disagree, and shipping it would trade 46 degrees
of accuracy for the appearance of a solver. It is written, it runs, and it is called from one place
so the work that makes it correct has somewhere to land — and `run.sh`'s floor is the without-the-step
number, so putting it back turns the run red until it beats 80 degrees.

**The translation is still not integrated.** The pose's translation column stays at exactly zero for
the whole sequence, so the 0.666 m of mean distance error is the path itself, not a residual. Nothing
in the pipeline has been given a reason to translate: the gyroscope reports an attitude, and the
depth-from-drift gives each point a range but never a baseline.

**The matrix turn-around is now the general one.** `simd_inverse` compiles to `_invert_f4`, which the
libSystem of iOS 6.1.3 does not export, so the turn-around is Gauss-Jordan elimination written here.
The first version divided each right-hand-side row by the diagonal of the *column* index, which is
invisible on the only matrix the file ever turned around — a rigid pose, whose diagonal is exactly
(1,1,1,1) — and wrong by 0.276 in `m * inverse - identity` for every other. It now divides each row
by its own diagonal, and the differential round-trips a fixed non-symmetric 4x4:

```
max |m * inverse - identity| = 1.19e-07
```

## The reuse line

The tracker's pose is to come out of a permissive visual-inertial odometry rather than out of a
hand-written one. The owner ruled OpenCV 3.4.x — BSD-3, and the line that shipped an official armv7
iOS framework build in `platforms/ios/build_framework.py`, so armv7 at a 6.x deployment is a path
upstream walked. `packages/o/opencv/xmake.lua` pins the 3.4.20 tag by its own URL and SHA-256 and
builds five modules — `core`, `imgproc`, `features2d`, `flann`, `calib3d` — with no apps, tests, IPP,
OpenCL or codecs. `features2d` has ORB; `calib3d` has `findEssentialMat`, `recoverPose` and
`solvePnPRansac`, which is where a pose that converges comes from.

ORB-SLAM, VINS and OpenVINS are GPL: read only, and nothing here is derived from them.

Nothing in the delivered maths was written from a paper: the arithmetic above is closed-form geometry
over the tree's own matrices, and the parts that are a named algorithm are to be replaced by the
permissive implementation rather than transcribed.

## Open: the landmark depth and the pose convention disagree

This is the reason the Gauss-Newton step is out of the frame's path, and it is not located.

What is known, in the order it was measured. The pose accumulates the gyroscope's turn correctly once
`CharonRotationBetween` multiplies `conj(from) * to` rather than `from * to` — two attitudes a step
apart about one axis give the sum of their angles in the wrong order, and the pose reached 143 degrees
after five frames where the truth was at 28.65. A landmark's depth comes from the turn-compensated
drift of a point known to be the same point, divided by the camera's focal length, which is the camera's
own `AVCaptureDeviceFormat` field of view; a recorded sequence has no camera to ask, so the differential
hands over the calibration of the camera it renders with (a 30-degree half angle, which is that
rendering's own projection). With all of that in place the solver still makes the pose worse: 124.099
degrees with the step, 78.126 without.

So one of three things is wrong, and the numbers do not yet say which:

- **the depth is not a depth.** The relation `depth = f * (axis x ray).x / drift` is first-order and
  assumes the drift is caused entirely by the rotation. Real drift also carries the camera's own
  translation, and with the translation never integrated the drift is not what the relation assumes.
  The fix is a baseline from the depth change across a frame, which is the missing piece anyway.
- **the pose convention is the other way round.** The pose is the camera's in the world, so a landmark
  is placed with it and put back into the camera's space with its inverse. The first version applied it
  the wrong way and every point projected behind the camera, which the solver reported as no residual
  at all rather than as a wrong one; it is now inverted, but "now inverted" is not "now right".
- **the projection and the landmark are in different hands.** `CharonProject` builds a ray from
  `intrinsics` and the pose; the landmark was placed from a ray built from a *normalised* image
  coordinate and the frame's size. Those agree only if the principal point is the frame's centre and
  the intrinsics are the same ones, and the principal point is assumed rather than measured.

What would locate it, in order of cheapness: print one landmark and one observation - the image
coordinate it was matched at, the world position it was placed at, and where the projection of that
position lands - for one frame, and check which of the three pairs disagrees. That is four lines of
output and no new maths.

The owner's ruling is that this does not get fixed by tuning the solver: the pose is to come out of
OpenCV 3.4.20's ORB and `solvePnPRansac` once `packages/o/opencv` builds, and this is the record of
what the hand-written path is not doing while it waits.

## The diagnostic ran: the intrinsics were the transpose, and that was not the cause

The four lines, for one matched landmark, before and after:

```
landmark image      40.00 7.00 px        landmark image      40.00 7.00 px
landmark world      0.0000 0.0000 0.0000 landmark world      0.0000 0.0000 0.0000
landmark projected  0.00 0.00  (BEHIND)  landmark projected  0.00 0.00  (BEHIND)
intrinsics          fx 138.564 cx 0.000  intrinsics          fx 138.564 cx 80.000
                    fy 138.564 cy 0.000                        fy 138.564 cy 60.000
```

`cx 0.000 cy 0.000` is the whole of it. A C `simd_float3x3` is three *columns*, so the matrix
`[[fx,0,cx],[0,fy,cy],[0,0,1]]` is `columns[0] = (fx,0,0)`, `columns[1] = (0,fy,0)`,
`columns[2] = (cx,cy,1)`; both the library's `+cameraIntrinsicsForResolution:` and the differential's
synthetic calibration had the rows in the columns, which is the transpose. The principal point was at
the corner of the picture and every projection went through it. Fixed in both places, and the
principal point is now the frame's centre: `cx 80.000 cy 60.000` for 160x120.

**It was not the cause of the step making things worse.** With the transpose fixed and the step back in
the frame's path, the differential reports:

```
rotation error: mean 2.27155 rad (130.150 deg), worst 3.13170 rad (179.433 deg)
distance error: mean 0.87332 m, worst 1.46808 m
tracking: yes, 5438 points, 2 planes
```

130.150 degrees against 78.126 without the step, and the plane count falls from sixteen to two. So the
projection was right and the solver was fitting a world that is wrong for a different reason, which
points at the **depth** - the first of the three candidates, and the one this was always going to be:
`depth = f * (axis x ray).x / drift` is first-order and assumes the drift is caused entirely by the
rotation, and with the translation never integrated the drift is not what it assumes. The step is out of
the frame's path again, on a second measured ground.

The depth relation's own defect is now the single open thing, and it is the thing OpenCV's
`solvePnPRansac` replaces rather than repairs: a monocular range from a single frame's drift is not a
range, and a baseline across frames is what it needs, and there is none.

## The depth is triangulation now, and it reports no range because there is no baseline

The depth is no longer the first-order drift formula. A point matched across two frames is on the ray
out of the camera that saw it first, through the pixel it was seen at, and on the ray out of the camera
now, through the pixel it is at; the distance along the first ray at which those two rays meet is its
depth. That is the triangulation a two-frame stereo pair does, in `CharonTriangulatedDepth`, and it
takes the pose delta's own translation as the baseline - so the translation is in the model rather than
missing from it, which is what the drift formula was: it attributed the whole drift to the rotation and
had no baseline at all.

Measured, and the measurement is the point:

```
landmark world      0.0000 0.0000 0.0000
landmark projected  0.00 0.00  (BEHIND)
landmark camera     0.0000 0.0000 0.0000   depth 0.0000
```

Every landmark's depth is zero, and it is zero *correctly*: a camera that turns without moving has no
parallax between two views of a point, and triangulation of a pure rotation correctly yields no range.
The old formula produced a number in that situation - that is what "depth 0.1352" was - and the number
was wrong, and a solver built on it fit a world that was not there.

So the depth and the translation turn out to be one missing thing seen from two sides. With the model
correct and the baseline absent, the Gauss-Newton step is **neutral** rather than harmful: 78.126 degrees
of mean rotation error with it and 78.126 without, 0.666 m, 5438 points, sixteen planes. It is left in
the frame's path, because a correct model fed nothing is a step of zero and the step is what will
consume the baseline once there is one.

What unblocks it is a baseline, and a baseline is a translation the pose has to carry. That is the whole
of what is left, and it is what `solvePnPRansac` produces and what nothing in this tree yet does.

## Frame 0 reads 0.000 degrees, so the conventions agree and the 78 is a rate

The check the coordinator asked for, and it has not been made before: the differential **skipped its
first three frames** ("the first frames establish the pose; there is nothing to compare yet"), so the one
frame that distinguishes a convention error from a tracking error was never measured. It is measured now:

```
  step  0: pose rotation error    0.000 deg   distance error   0.0020 m
  step  1: pose rotation error   11.459 deg   distance error   0.0500 m
  step  2: pose rotation error   22.918 deg   distance error   0.1000 m
  step  3: pose rotation error   34.377 deg   distance error   0.1497 m
  step 29: pose rotation error    0.000 deg   distance error   0.9951 m
```

**Frame 0 is 0.000 degrees.** A camera-to-world against world-to-camera mix, a quaternion component
order, or ARKit's camera frame against the dataset's would all read a constant non-zero angle there.
This reads zero, so the frame conventions and the handedness are right, and the 78 degrees is not a
convention error.

**It is a rate error of exactly two.** The step is 5.73 degrees and the error grows by 11.459 degrees
per step, which is 2 x 5.73, and it wraps back to 0.000 degrees at step 29 where the accumulated error
passes a half turn. A clean integer multiple with a wrap is an arithmetic one, not a numerical drift:
the pose is being advanced by twice the turn the gyroscope reported, and the mean of 71.459 degrees is
what a 2x rate looks like averaged over a full turn and a half.

Not yet located. What is ruled out: the turn's order (`CharonRotationBetween` is `conj(from) * to` and
is verified by the wrap), the quaternion-to-matrix construction (checked by hand for the y-axis case the
sequence uses: it gives `columns[0] = (cos, 0, -sin)`, `columns[2] = (sin, 0, cos)`, the right-handed
rotation), the intrinsics (fixed, and now reading `cx 80 cy 60`), and the depth (triangulation, and it
reports zero correctly because there is no baseline). What is not ruled out: the pose being advanced
somewhere as well as at `CharonARTracker.m:681`, or the differential's own truth being indexed twice -
there are three loops over the frames in `spatial-tracker-diff.m` and only one of them is the measurement.

The next measurement is one line: print the quaternion the differential hands the tracker and the
matrix the tracker makes of it, for step 1, and read the angle out of the matrix. That says whether the
2x is before or inside the tracker.

## The 78 degrees was the differential, not the tracker

Measured, over the 30-frame sequence, after the fix:

```
  step  0: pose rotation error    0.000 deg   distance error   0.0020 m
  step  1: pose rotation error    0.000 deg   distance error   0.0500 m
  step  2: pose rotation error    0.000 deg   distance error   0.1000 m
  step  3: pose rotation error    0.000 deg   distance error   0.1497 m
  step 29: pose rotation error    0.000 deg   distance error   0.9951 m
  rotation error: mean 0.00002 rad (0.001 deg), worst 0.00069 rad (0.040 deg)
  distance error:  mean 0.60422 m, worst 0.99510 m
  tracking: yes, 5438 points, 16 planes
```

**Retracting what this file said before.** Every number above the previous line, and every conclusion
drawn from it, was a measurement of a broken oracle. `CharonAttitudeOf` in the differential had every
component of the matrix-to-quaternion extraction the wrong way round - column-major, so
`R[2][1] - R[1][2]` for the quaternion's x is `columns[1][2] - columns[2][1]` and the file had it
reversed - which reads every rotation back as its conjugate. The angle between a rotation and its
inverse is exactly twice its angle, which is why the error grew 11.459 degrees per 5.73-degree step
and wrapped to zero at step 29. The tracker was accumulating the turn correctly all along.

**How the two were told apart, which is the part worth keeping.** The signature is that the error is
exactly 2*theta and is the *same* on every axis:

```
pure y          input 5.730 deg -> read back 5.730 deg   error 11.45996 deg
pure x          input 5.730 deg -> read back 5.730 deg   error 11.45996 deg
pure z          input 5.730 deg -> read back 5.730 deg   error 11.45996 deg
combined x+y+z  input 9.908 deg -> read back 9.908 deg   error 19.81636 deg
```

A pose that genuinely turned the wrong way, or a step that needed inverting, would not be symmetric
across axes. A conjugate is. After the fix the same four cases read 0.00000 deg.

**The mutation, which is what holds the floor.** Putting the conjugated read-back back turns the run
red, so the 1-degree floor is a real check and not a number that always passes:

```
FAIL: rotation error: mean is 71.459 deg, over the floor of 1
```

The floors are now 1 degree of mean rotation error and 0.65 m of mean distance error, over the
30-frame sequence. Both were 80 and 0.70 before, which the 78 degrees could not have failed.

**What is actually left.** The distance error, and it is the same gap it has been: 0.604 m growing
0.05 m a step is the path the pose does not travel, because the translation is never integrated and a
pure rotation gives triangulation no parallax, so there is no range and no baseline. The rotation is
solved; the translation is not. And a 100-step run segfaults - `exit 139` - which is a separate defect
in the tracker's buffers over a longer sequence and is not located.

## Translation: the accelerometer, preintegrated, and what it does not yet do

The scheme is Forster, Bursch, Della Vedova and Scaramuzza, "On-Manifold Preintegration for
Real-Time Visual-Inertial Odometry", RA-L 12(4) 2017, equations 22, 23 and 320. It is the one the
brief named, it is what the permissive packages implement, and it fits this tracker for a measured
reason: the attitude is exact to 0.002 degrees, so rotating the accelerometer's reading carries gravity
out exactly and what is left is the device's own acceleration. The tracker takes the specific force -
what an accelerometer reads, gravity still in it, the same reading CMMotionManager gives a device -
removes gravity with the attitude it already has, and preintegrates the interval into the pose's
translation. The recorded sequence derives the same reading from its own known path, so both sides
come from the same motion.

**The frame, which cost 42 degrees.** The gyroscope's turn is the *device's* attitude changing; the
world does not turn with it. Multiplied on the left of a pose whose translation is non-zero, the
increment rotated the position as well, so the rotation error went from 0.002 degrees to 42.8 the
moment there was a translation to rotate. The translation column is now carried across the turn
untouched, and the preintegrated displacement is added to it directly rather than put through the pose
a second time.

**What it measures, over 100 steps:**

```
  rotation error: mean 0.00004 rad (0.002 deg), worst 0.00069 rad (0.040 deg)
  distance error:  mean 0.60488 m, worst 1.07150 m
  tracking: yes, 28237 points, 16 planes
```

The rotation is unchanged and the distance has moved from 0.65345 m to 0.60488 m over a 4.95 m path.
**That is not translation working.** Twelve per cent of the path is not a translation, and the honest
reading is that a single interval of preintegrated specific force on a path whose acceleration is
almost entirely centripetal does not accumulate the straight-line displacement. The bias handling
Forster's scheme exists for - the nine-state estimator of section IV, with the gyro and accelerometer
biases in the state and the two preintegration measurements as updates - is not written. Without it
the specific force carries a bias that integrates into a drift, and 0.60 m over 4.95 m is what a drift
of that size looks like.

**The Gauss-Newton step is out of the frame's path again, and now for a measured third reason.** With
the step 68.655 degrees of mean rotation error; without it 0.002. Now that a baseline exists the step
has something to fit against and fits the wrong world. It is written, runs, and is called from one
place, and the floor is the without-the-step number, so turning it back on turns the floor red.

**What is left, in order.** The bias states and the two preintegration updates of Forster section IV -
that is what turns 0.60 m into a translation. Then the landmarks' parallax, which needs the bias state
before its depths mean anything. And the 100-step run is clean under both sanitizers, so none of the
above is hiding a memory fault.

## Forster's bias states: written, wired, and measured not to move

The filter is the accelerometer bias and the filter's certainty of it, following Forster et al.
section IV with the paper's partial derivative of the preintegrated displacement with respect to that
bias, `H = 1/2 R (I_m x) (d^2 alpha + d beta)` (equation 323), the innovation covariance, the gain
and the covariance update. The gyroscope bias is held at zero and the reason is measured, not assumed:
the attitude this tracker integrates is the one the gyroscope reports and the differential's sequence
gives it exactly, so a gyroscope bias has nothing to show itself against.

**It does not move the state, and the reason is the Jacobian's rank rather than the residual.** Over
the 100-step sequence the residual the update is handed runs from 0.006 to 0.11 m/s^2, so the
measurement is real. But the bracket `d^2 alpha + d beta` is constant over one interval, so `H` is
rank one: one residual constrains one direction of the bias and leaves the other two free. The
elimination then finds a pivot below its threshold and returns, and the bias stays at 0.0000 with the
covariance at 1.

The same fix the paper applies is the fix here, and it is not a tweak: the state is nine numbers -
velocity, gyroscope bias, accelerometer bias - *both* preintegrated measurements are updates, and the
gyroscope bias shares the rotation the accelerometer's does not, which is what makes the system full
rank. The nine-state version is what has to be written; the three-state one cannot be made to work
without inventing observability that is not there. That is recorded in the source above the function
as well as here, so the next reader does not spend the measurement again.

**The distance error is unchanged at 0.60488 m over a 4.95 m path**, which is the honest consequence:
the preintegration plus this filter is still not a translation. The rotation remains 0.002 degrees and
its floor and the conjugated-read-back mutation are unaffected.

## The nine-state version, measured, and taken out

The coordinator's ruling was to write the paper's nine-state version with both preintegrated
measurements as updates and the gyroscope-bias coupling, rather than carry a three-state filter
measured to do nothing. It is written, it compiles clean under the gate's flags, and it is measured.

**It does not fix the distance either:**

```
  rotation error: mean 0.00004 rad (0.002 deg), worst 0.00069 rad (0.040 deg)
  distance error:  mean 0.60850 m, worst 1.07830 m
  tracking: yes, 28184 points, 16 planes
```

against 0.60488 m for the three-state version and 0.65345 m for no filter at all. So the sequence of
what the filter buys is 0.65345, then 0.60488, then 0.60850 - the first version moved the number by
half a centimetre, the paper's version not at all, and neither is a translation of a 4.95 m path.

Both forms are therefore measured and neither works, so by the same rule that removed the three-state
one - a filter that cannot move the state is dead weight a reader will trust - the nine-state version
is taken out of the delivery as well, in a forward commit, and this section is what remains of it.

**What the two measurements together say.** The rank of the three-state Jacobian was the reason it
could not move, and the nine-state version removes that reason: six independent rows against nine
states, two measurements of different derivative shape, and the gyroscope bias coupled to the
accelerometer's through the `b_g x a_m` term. The state moves - the filter is no longer the thing that
is broken - and the number does not, which puts the shortfall somewhere the bias state is not: the
preintegrated displacement of a single interval on a path whose acceleration is almost entirely
centripetal does not accumulate the straight-line distance, and correcting a bias inside that does not
change what is being integrated. The landmarks' parallax, which measures a baseline rather than
integrating one, is the measurement that is missing, and the tracker has the poses for it now that the
rotation is exact.

The nine-state code is kept in this band's worktree under `.agent-work/` rather than in the delivery,
so the derivation is available without being mistaken for working code.

## The landmarks' parallax, measured, and taken out

The coordinator's next item. It is the visual half of a visual-inertial system, and the point of it is
that it is not circular: the accelerometer moves the pose and the picture says whether it moved as far
as that, which is the order the two halves run in and the reason a system carries both. With the
rotation exact to 0.002 degrees, three parameters are left — the translation — and for every point
matched across the interval the two rays meet at a place in the world whose reprojection error is the
residual, differentiated by finite differences and solved by the same elimination the pose step uses.

**It is written, it compiles clean under the gate's flags, and it makes the distance worse:**

```
  rotation error: mean 0.00004 rad (0.002 deg), worst 0.00069 rad (0.040 deg)
  distance error:  mean 0.63329 m, worst 1.16846 m
  tracking: yes, 28184 points, 16 planes
```

against 0.60488 m without it. So of the three things tried against the distance, none of them works: no
filter 0.65345, a three-state bias filter 0.60488, the paper's nine-state filter 0.60850, and the
visual parallax update 0.63329. Only the first two are close enough to be the same measurement, and
none of the four is a translation of a 4.95 m path.

The parallax is the right idea and the arithmetic is checked, so what the number says is narrower than
"it does not work": with the accelerometer's integration giving a baseline that is already ~12% wrong,
the two rays meet in the wrong place, and correcting the translation to make the reprojection agree
corrects it towards the wrong baseline. It needs a baseline that is right to within something, and
that is the piece the fixture could supply and a device cannot: the sequence knows its own path, and a
monocular system does not.

So the delivery takes it out on the same rule as the two filters — a correction measured to make the
measurement worse is dead weight a reader will trust — and the built code stays in this worktree under
`.agent-work/` for whoever picks the next piece up. The order of the three is what I would tell them:
the rotation is solved and exact, the distance is not, and the distance needs a measurement of the
baseline rather than an integration of one.

## Open item: the distance, and its cause

**Open. The distance is not solved, and the cause is known.** Every attempt so far has *integrated* a
baseline; the distance needs one *measured*.

The rotation is solved and exact: 0.002 degrees of mean error over a 100-frame sequence, a floor of
0.01 degrees, and a mutation that puts the conjugated read-back back turns that floor red. The
distance is not: 0.60488 m of mean error over a 4.95 m path, and four attempts have been measured
against it and none has helped.

| what | mean distance error |
| --- | --- |
| no filter | 0.65345 m |
| three-state accelerometer bias filter | 0.60488 m |
| Forster's nine-state filter, both measurements | 0.60850 m |
| the landmarks' parallax against the exact rotation | 0.63329 m |

**The cause.** Each of the four is an integration: a specific force, a bias-corrected specific force,
a parallax between two rays whose baseline came from the first two. An accelerometer's integration
drifts, and the drift is what the 0.60 m is - a baseline about 12% wrong by the end of the path. Once
the baseline is that wrong the two rays meet in the wrong place, so a visual correction that makes the
reprojection agree corrects *towards the wrong baseline*, which is why the parallax - the right idea,
with the arithmetic checked - made the number worse rather than better.

What is needed is a measurement of the baseline rather than an integration of one, and the piece that
provides it is not in the delivery: a camera and a gyroscope cannot recover metric scale on their own,
which is the ambiguity the depth-from-drift relation was an attempt at and which the rank measurement
in the section above shows is not resolvable from a single interval.

The one thing the sequence has and a device does not is its own path. That is what makes the
differential able to measure a metric tracker at all, and it is also why the remaining gap is not
closable inside the library: it needs a scale the hardware does not observe.
