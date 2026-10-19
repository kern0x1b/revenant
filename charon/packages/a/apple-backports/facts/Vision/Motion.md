# The motion requests of Vision: optical flow and trajectories, what the host answers

Measured by `tests/backports/host/vision-motion/motion.m` (its answers are in `expected.txt`, checked by `run.sh`).
Both requests and their observations are on the host; the port has none of them, and the rows that name them stay owed.

## Optical flow (`VNGenerateOpticalFlowRequest`)

- On a 64x64 target and a 64x64 source, with `computationAccuracy` high, the request answers one
  `VNPixelBufferObservation`, in a 64x64 buffer of format `kCVPixelFormatType_TwoComponent16Half` (843264102).
  The two components are the horizontal and vertical displacement, as half-precision floats.
- The values do not track a known shift. A textured picture shifted by 3 pixels, a picture not shifted, and a
  binary square shifted by 3 all give medians of about -2 to 2 in the vertical component, a NaN at some points, and
  no consistent horizontal displacement (the unshifted picture gives a horizontal median of NaN). The sign and the
  size of the displacement that Vision's output means are not established by this measurement, so the flow is not
  implemented: an implementation would have to reproduce values this measurement cannot check.
- A second measurement, with a band-limited random texture of 128x128 and known shifts (the target is the source
  sampled bilinearly at x - dx, y - dy; the output is 128x128, read as half-precision and summarised over the central
  32x32): the first component (slot 0) is noise, with medians of 0.000 at every shift, means in the hundreds or
  thousands at some shifts, and NaNs even at zero shift. The second component (slot 1) is the only one that follows
  the shift, and it does not follow it linearly or by axis: a shift of +1 px in x or in y gives a median of about
  +1.9, a shift of -1 px gives about -1.0, zero shift gives about -0.9, and the response saturates near 2.3 by 4 px.
  Diagonal shifts agree across three seeds to about 0.01. Gratings of one orientation give output that does not
  depend on the shift along their stripes, but the sign convention does not hold on them either.
- So the component that moves is not established as dx or dy, the sign and the scale in pixels per output unit are
  not established, and the rest value (-0.9 on the texture, not 0) is unexplained. The flow stays owed.

## Trajectories (`VNDetectTrajectoriesRequest`)

- The request is run on a timed `CMSampleBuffer` (a bare pixel buffer answers error 18, "No valid
  presentationTimeStamp was available for this image").
- Requested with a frame analysis spacing of 1/30 s and a trajectory length of 3, the request reports a trajectory
  length of 5.
- On a 16-pixel square moving one pixel per frame, the first `VNTrajectoryObservation` appears at the seventh frame
  (frame index 6), and one appears on every frame after it. Its confidence is 0.000.
- The reported length is `max(requested, 5)`: 3 reports 5, 8 and 10 report themselves. The first observation is
  at 0-based frame index `L' + 1`, where `L'` is the reported length (6 for 5, 9 for 8, 11 for 10), and one
  observation follows on every frame after it.
- Each observation's `detectedPoints` holds `L'` points, the newest `L'` detections, so the window slides by one
  point per frame.
- `equationCoefficients` (`y = ax^2 + bx + c`, in normalised coordinates, origin bottom left) are the least-squares
  parabola through the detected points. For the first observation (5 points) they equal the fit of those points to
  1e-5, and for observations 1 to 12 they equal the fit of every point detected since the first one (6 to 17
  points) to 1e-5. From observation 13 on they do not follow that rule: they match fits of short runs of the most
  recent detections (3 to 8 points), and no single rule is established from one run. The measurement program is
  in `.agent-work/runs/traj` (not committed; `traj3.m`, `cumfit.c`, `suffixfit.c`).
- The detections are not one per frame. On the parabola plant (a 16-pixel square moving about 2.5 px per frame in a
  128-pixel frame), the first window has a gap of about two frames between its fourth and fifth points, so a frame
  gives no detection, and the rule for that is not measured.
- A detected point lies about 1 px in x and 1 px in y from the object's true centre, and the offset depends on the
  move (integer moves of 1 and 2 px put the point at the leading or trailing edge), so the point rule is not
  established.
- `confidence` is 0.000 on a straight-line track and 0.9915 to 0.9999 on the parabolas measured, rising with the
  number of observations. `movingAverageRadius` on the parabola is 0.092 at the first observation and about 0.063
  by the thirtieth.

The port has no trajectory request or observation; the registry names this.

## What is owed, and why

Both requests and the trajectory observation stay owed. For optical flow, the values above do not reduce to a shift.
For trajectories, the timing, the reported length, the window of detected points and the first-observation frame are
measured and could be implemented; what stops an implementation is the detection itself (the point rule, the frames
with no detection) and the fit after observation 12, none of which one plant settles. The measurements in this file
are the facts an implementation would be checked against.
