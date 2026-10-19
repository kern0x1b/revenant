# Vision's point results of iOS 14: VNDetectedPoint and VNRecognizedPoint

These two classes are the points a point-finding request writes. Their initialisers are marked `NS_UNAVAILABLE` in the SDK's
`VNDetectedPoint.h`, so an application never makes one; the port makes them with its own factories
(`revenant_pointWithX:y:confidence:` and `revenant_pointWithX:y:confidence:identifier:`). The factories are the only way in, and
their names carry the `revenant_` prefix, so they are not part of the surface.

## What the class is

- `VNDetectedPoint` is a `VNPoint` with a `confidence` (a `VNConfidence`, a float) that is readonly. The superclass is read from
  the IR's `super` row (`VNPoint`), as every superclass in this family is.
- `VNRecognizedPoint` is a `VNDetectedPoint` with an `identifier` (`VNRecognizedPointKey`, an `NSString`, readonly and copied).
  The identifier is the label the model that found the point gave it.

## What is measured

`tests/backports/host/vision-results14` compares the header-declared surface of both classes, member by member, between the
host's Vision and the port's sources:

- the superclass of each class;
- the type encoding of each member the headers declare, the inherited ones included: `+new`, `-init`, `-initWithX:y:`,
  `-initWithLocation:`, `-confidence`, `-identifier`;
- the attributes of each declared property (`confidence`, `identifier`), without the ivar name.

The member list is `surface.tsv`, read from the IR of the SDK's headers (`tools/found`, `IR_SDK=<iOS 26.2 SDK> decls Vision`,
21 tab columns). Its lines are the IR's `super` rows for the two classes (`super`), their `method` rows for the class members
and the initialisers (`class` for `(cm)`, `instance` for `(im)`), their `property` rows (`property`), and the getters of those
properties, which the IR records as `accessor` rows (`instance`). The getters are listed by hand, from those accessor rows.

The run prints `port: all 10 declared members ... are the host's`, and a plant that gives `VNDetectedPoint`'s confidence getter a
`double` return turns it red with `plant: the changed member is seen: 1 line(s) differ`.

The four `NS_UNAVAILABLE` initialisers are answered by the implementation the runtime resolves them to, as the MetalKit and
Core ML rows answer theirs (facts/CoreML/Unavailable.md): `+new` and `-init` are NSObject's on both sides; `-initWithX:y:`
and `-initWithLocation:` are `VNPoint`'s, inherited, on both sides.

## What is not measured, and what the port does not carry

- The host's `VNDetectedPoint` implements members the headers do not declare: `-initWithLocation:confidence:`, `-hash`,
  `-isEqual:`, `-transformedWith:`, and `+supportsSecureCoding`/`-copyWithZone:` on the class itself. None of them is in the
  surface the test compares, and the port does not carry the undeclared ones. `-initWithLocation:confidence:` is the
  designated initialiser the host's own factories use; the port's factory plays that role without a public selector.
- The coding of the two classes is the port's own: `confidence` and `identifier` are encoded with the `VNPoint` coding and
  decoded back. The host's encoded form was not read, so the bytes are not compared, and a decoded point's values are the
  port's round trip.
- The values of the points are whatever the caller gives the factory. The point-finding requests that make these points
  (body and hand pose, and the rest of the iOS 14 requests) are not carried; their rows say what each needs.

## Observations that only a request makes: the host's answer to -init and +new

`VNTrajectoryObservation`, `VNRecognizedPointsObservation`, `VNHumanBodyPoseObservation` and `VNHumanHandPoseObservation`
have `-init` NS_UNAVAILABLE in their headers or inherit a nil answer. Measured on the host (macOS, this machine's Vision,
a bare tool that calls `[[C alloc] init]` and `[C new]` for each class by name): all four answer nil, so no application
can make one of them, and the only instances are the results of the requests that produce them. Those requests are the
rows that say what each needs (the trajectories request, and the two pose requests). Their rows are `owed` with this file
as their `facts`, and they stay so until a request that produces them is carried and measured.

`VNHumanObservation` (15.0) is the contrast: its `-init` and `+new` answer objects on the host, so it can be made directly,
and it is not in this section. `VNVideoProcessor` (14.0) also answers objects for `-init`, though its `-init` is declared
NS_UNAVAILABLE in the header; the host's answer is the inherited one, and the class is not yet carried.
