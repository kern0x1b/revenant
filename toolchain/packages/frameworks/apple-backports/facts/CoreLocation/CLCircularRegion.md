# CLCircularRegion, and CLRegion's notifyOnEntry and notifyOnExit, iOS 7

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction:
`-[CLCircularRegion initWithCenter:radius:identifier:]` at `0x187d90c80`, `-[CLRegion initWithIdentifier:]` at
`0x187d8f850`, `-[CLCircularRegion containsCoordinate:]` at `0x187d912f8`, `-[CLRegion notifyOnEntry]` at `0x187d90a0c`;
and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2, through the probe the tests of this class are built from.

## What is read of the newest release

- A circular region is a region with a type: `-[CLCircularRegion initWithCenter:radius:identifier:]` sends
  `-initWithIdentifier:` to `CLRegion` and then writes the region type 1, the centre and the radius into the region's own
  internal object. `-containsCoordinate:` and the accessors read that object; `CLCircularRegion`'s
  `-containsCoordinate:` sends the message on to `CLRegion`'s.
- `-[CLRegion initWithIdentifier:]` keeps the identifier as a C string of at most 512 bytes, UTF-8, and gives up
  (releases itself, answers nil) for one that does not fit. It sets both `notifyOnEntry` and `notifyOnExit` to YES.
- `-notifyOnEntry`, `-notifyOnExit` and `-[CLBeaconRegion notifyEntryStateOnDisplay]` read one byte of that object under
  `@synchronized`.

## What the port does

iOS 6.0 already has the circular region, as `CLRegion` made with `-initCircularRegionWithCenter:radius:identifier:`, and
the same centre, radius, identifier and `-containsCoordinate:`. `CLCircularRegion` here is a subclass of `CLRegion` whose
initializer sends that one, and whose centre, radius and containment answer what the release's own do. A copy of it is a
`CLCircularRegion` again: the release copies with the class of the receiver. `notifyOnEntry` and `notifyOnExit` are kept
as associated values, YES until set.

What comes out of the release's manager is not one of these: the regions a manager hands to its delegate, or lists in
`-monitoredRegions`, are plain `CLRegion` objects, so `isKindOfClass:[CLCircularRegion class]` on them is NO. An application
that tests for the class of a region it did not make gets the answer of iOS 6.

`notifyOnEntry` and `notifyOnExit` are inert. The release's manager delivers both kinds of notification for every region
it monitors, and there is nothing in the backports between the manager and the delegate to leave one out.

The port's own stand-in (`CoreLocation/CLRegion+Notify.m`) stores each flag as an associated object of the region. It
answers the stored value on the region it was set on, and the copy does not keep it: measured with the port's file, set
to NO, the original reads NO and its copy reads YES, where the host's copy keeps NO. The rows stay owed until a copy
keeps the flag, and the region monitoring that would act on it is carried.

## What was measured

Emulated iOS 6.0 and an iPad 2 on iOS 6.1.3, the same answers on both: `CLCircularRegion` comes from
`libCoreLocationBackports.dylib`; a region of centre (37.33, -122.03), radius 250 and identifier `own` answers those
back; it contains its centre and does not contain (40, -100); its copy is a `CLCircularRegion`; both notify flags start
YES, and after `notifyOnEntry = NO` the entry flag answers NO and the exit flag YES. A plain `CLRegion` made with
`-initCircularRegionWithCenter:` answers the same centre, radius and containment, and its copy is a `CLRegion`.
