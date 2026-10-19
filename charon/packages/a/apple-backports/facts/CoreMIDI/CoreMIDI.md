# CoreMIDI from iOS 9 to 14: blocks, properties and endpoints by protocol

iOS 9 gave CoreMIDI the block forms of its client and its ports, `MIDIClientCreateWithBlock`, `MIDIInputPortCreateWithBlock`
and `MIDIDestinationCreateWithBlock`, and iOS 14 gave it Universal MIDI Packets: the protocol-aware input ports, virtual
destinations and sources (`MIDIInputPortCreateWithProtocol`, `MIDIDestinationCreateWithProtocol`,
`MIDISourceCreateWithProtocol`), the lists those carry (`MIDIEventListInit`, `MIDIEventListAdd`, `MIDISendEventList`,
`MIDIReceivedEventList`) and the property that names an endpoint's protocol, `kMIDIPropertyProtocolID`. The release of this
port, iOS 6.1.3, has the function forms of the first and none of the second: its CoreMIDI is the one of iOS 4.2 and carries
MIDI 1.0 bytes only.

## What is built on what

- `MIDIClientCreateWithBlock` is the release's `MIDIClientCreate` with the block carried in its reference constant. The
  block is copied once and kept for as long as the client lives. The release does not tell this library when the client ends,
  so the copy is released when the object is found gone: the rows of CharonMIDIPorts.m are swept whenever the library makes
  another object, and a client that answers paramErr to a UniqueID read is gone (below). A NULL
  block is accepted and returns noErr, as macOS does (measured, oracle/nullargs.m: `0`). A protocol that is neither 1.0 nor
  2.0 answers `paramErr` here; macOS does not answer it, it terminates the process (measured, the same probe).
- `MIDIInputPortCreateWithBlock` and `MIDIDestinationCreateWithBlock` are the release's `MIDIInputPortCreate` and
  `MIDIDestinationCreate`, with the same carrying.
- The protocol-aware ports and endpoints are the release's own, with a read procedure of this library that converts the
  packets it receives to Universal MIDI Packets in the protocol asked for (facts/CoreMIDI/Translation.md). The protocol of a
  source or destination is kept as its `kMIDIPropertyProtocolID` property, which is a string key this release stores and
  reads with `MIDIObjectSetIntegerProperty`.
- `MIDISendEventList` and `MIDIReceivedEventList` convert the list to MIDI 1.0 packets and hand them to the release's
  `MIDISend` and `MIDIReceived`. A list that converts to no bytes is sent as nothing and answers `noErr`, as the
  function does for an empty list.
- The event list builders are a buffer this library fills (facts/CoreMIDI/EventList.md).

## Constants

Both string constants are the values macOS CoreMIDI gives them, read from the host's own framework by
`tests/backports/host/coremidi/differential.m` and recorded in `host/coremidi/oracle`:

- `kMIDIPropertyNameConfigurationDictionary` is `nameConfigurationDictionary` (iOS 13).
- `kMIDIPropertyProtocolID` is `protocol` (iOS 14).

## Disposed objects (macOS 27.0.1, oracle/removal-notify.m, removal-notify-macos.txt)

- A destination, a virtual source and an input port that are disposed answer a UniqueID read with paramErr (-50), as a
  reference that never existed does. A live destination or source answers noErr; a live input port answers -10835 (a
  port has no UniqueID). So a reference that answers -50 is gone. The status is the OSStatus of the read; the UniqueID
  value is meaningful only with noErr.
- A destination's and a source's removal is announced to the client's notify proc as kMIDIMsgObjectRemoved, after the dispose
  call has returned, on the main thread, followed by kMIDIMsgSetupChanged. An input port's dispose announces nothing.
- A send to a disposed destination delivers nothing to its block (0 calls; the live control gives 1).
- Measured on the emulated 6.1.3 (tests/backports/emulate/coremidi/app/main.m, built with CHARCOREMIDI_PROBE=1; the status of
  each read, the value only with noErr): a live client -10835 (it has no UniqueID), a live destination 0 and a live virtual
  source 0, a live input port -10835; each of the four after its dispose -50. The same answers as macOS where macOS was
  measured (a client's liveness was not measured on macOS: its dispose is only seen in the host differential, where the block
  a client held is released once the library has swept it). A destination's reference after a dispose was not reused by the
  next destination in the one run (first 372756, second 372757, with the references of the run before them in sequence).
- The removal notification is the other way the release says an object is gone, and it is measured on 6.1.3 too (the same
  probe): a destination (childType 3), a source (childType 2) and an entity (childType 1) post kMIDIMsgObjectRemoved to a
  client's notify proc, on the main run loop, and the release posts it to a client made after the object was disposed as well
  (all six removals of the run reached the one client that listened). An input port and a client announce nothing: the
  port (ref 372753) and the first client (372750) were disposed in that run and none of the six notifications names them, as an
  input port's dispose announces nothing on macOS. The library keeps the UniqueID sweep
  because it covers the objects the notification does not, and a second channel for the destinations and sources would only
  bring the release of a block forward to the moment of the dispose, which needs a client of the library's own and a running
  main run loop; neither is needed for the sweep.
- The owned row also carries the stamp the library wrote on its object when it took it, so a reference the release gives to a
  new object after a dispose is not taken for the old one (CharonMIDIPorts.m, charon_object_check; "Which identity" below). The
  UniqueID is not part of a row: it is the creator's to set (MIDIServices.h, kMIDIPropertyUniqueID), and an application that sets
  it on its own destination has the same live object.
- The library learns of a dispose by reads it makes itself: on each in-process delivery, right before its block is called
  (charon_drain), and on each creation's sweep (charon_sweep, a window of rows). The release gives it no call for a dispose, and the
  notification above goes to a client's notify proc, not to the library.

## What is not built here

What the registry (registry/CoreMIDI/*.json) says is not an implemented API, counted on 2026-10-10 over the 51 rows of the
eight files (`xmake l` over the files, `json.loadfile`): 41 are `implemented`, 8 are `inert` and 2 are `owed`.

- `owed` (not exported under their names): `MIDIBluetoothDriverActivateAllConnections` and `MIDIBluetoothDriverDisconnect`
  (iOS 16). The bodies are built (MIDIBluetooth16.m, `charon_bluetooth_*`) and the central has never run on a device; see
  Bluetooth.md.
- `inert` (the type exists, and does nothing that a MIDI-CI transport would do, because the port has none; each logs once
  when an action is asked for): `MIDICISession` (iOS 12), `MIDICIDiscoveredNode`, `MIDICIDiscoveryManager`, `MIDICIResponder` and
  `MIDICIProfileResponderDelegate` (iOS 14), `MIDICIDevice`, `MIDIUMPCIProfile` and `MIDICIDeviceManager` (iOS 18); see MIDICI.md
  and UMPClasses.md.
- Built, and no longer listed as missing: `MIDISendUMPSysex` and `MIDISendUMPSysex8` (MIDISysex17.m), `MIDIEventListForEachEvent`
  (Visitor.md), and the `MIDIUMP*` endpoint, function-block and manager classes of iOS 18 (MIDIUMP18.m, UMPClasses.md).

## Virtual endpoints on the emulated iPhone 4S at 6.1.3: which processes the release lets make them

Measured with `tests/backports/emulate/coremidi` (`run.sh`, which runs `run-app.sh`: `xmake emulate -d iPhone4,1 -r 6.1.3`, time scale 10):

- A daemon (`/usr/libexec/charoncoremidi`, started by launchd, no bundle) is refused: the release's own `MIDISourceCreate`
  returns -10844 (kMIDINotPermitted), and so do this library's protocol endpoints. The round trip was FAIL (7 failures) as a
  daemon. The command-line tool that made that run is retired (the commit "Retire the CoreMIDI round-trip command-line tool"),
  so no command-line form of the round trip is kept. The guest's MIDIServer runs (it is spawned by launchd at boot).
- The same probe as an application (`run-app.sh`: an installed bundle, launched through SpringBoard) passes:
  `roundtrip: PASS (0 failures)`, `application exit: 0`; the control `MIDISourceCreate` answers 0.
- Isolated, for the application:
  - without an active audio session (no AudioSessionSetActive): still PASS. The audio session is not needed.
  - without `UIBackgroundModes` = `audio` in its Info.plist: refused (-10844 for the source, the destination and the control).
    The declared audio background mode is what the release checks.
- Not isolated: whether the daemon is refused for having no bundle, for not having the mode, or for running outside SpringBoard.
  The daemon has neither the mode nor a bundle, so the two cases are not separated; both are missing in the daemon.

So the emulated release can give virtual endpoints, to an application that declares the audio background mode. A port daemon
cannot make one. An in-process substitute is therefore not needed for an application; a daemon of the port that needs an
endpoint has to be an application with the mode (the BLE central, for one, lives in the application that loads the library).

The 2026-10-09 result of the daemon run is the record of the first refusal; the application run is the one that answers the
question. On macOS a command-line tool creates virtual endpoints (oracle/*.m), and the MIDI-CI discovery client is refused
(-10844) there, as the MIDI-CI facts say.

## Evidence

The translation rules and every measurement behind them are in facts/CoreMIDI/Translation.md; the event list rules are in
facts/CoreMIDI/EventList.md. The host differential that holds the library to macOS is `tests/backports/host/coremidi/run.sh`.

## Which identity an owned row uses (decision, 2026-10-10; oracle/stamp.h, oracle/stamp-macos.txt)

A row must tell its object from a reference the release gave to a new object, without taking an object whose creator changed
its UniqueID for a new one (the first rule did: it freed the port and block of a live destination whose application had set
its UniqueID, while the release still held them). Chosen: the library writes a private integer under its own key
(`charon.owner`, CHARON_OWNER_KEY) when it takes an object, and a row is the same object while the key reads back the value.

Measured with the same program (oracle/stamp.h) on macOS 27.0.1 (oracle/stamp-macos.txt) and on the emulated 6.1.3 (run folder
of the band, app-stamp.out):

- Client, input port, output port, destination and source all accept the write (status 0), read it back, and list the key in
  MIDIObjectGetProperties. Before the write the read is -10835 on every kind, after the dispose -50 on every kind.
- A destination or source whose creator then sets its UniqueID (status 0, the UniqueID reads the new value) keeps the stamp.
- Round 9 (host only, macOS 27.0.1; probe-owner.out in the run folder v-midifix9/l5/out): a destination the release made and the library
  did not stamp answers -10835 for the owner key (value 0); a destination the library made answers noErr with its stamp; after the
  dispose both answer -50 for the owner key, and the release destination answers -50 for the UniqueID too. A reused reference was not
  produced on the host, so the library's branch for a new object without the stamp (charon_object_check, kMIDIUnknownProperty on a
  stamped row) is by reading.
- Churn: 300 destinations, 300 sources, 300 input ports and 100 clients made and disposed, with a few kept alive across it: no
  reference was seen again and every reference was above the one before (macOS and 6.1.3 alike). A reuse was never observed;
  the stamp is for the case that cannot be excluded, and its failure mode (an in-process delivery into the block of a destination
  that is another object now) is a delivery into the application's freed context.
- Cost: one write per owned object. The release announces the write to the clients of the process as one property change
  (macOS: object type 3 and 2 for a destination and a source, -1 for ports and clients, property name `charon.owner`).

Alternatives, and why each lost:

- The UniqueID read at the creation: an application may set it (documented as the creator's job), and the rule then freed a
  live object's port. It was the rule of the second round (review r2 N11 proposed it; review r3 retracted it).
- paramErr alone: simple, and free of the write and the notification, but a reference that was given to a live new object reads
  noErr, so the old row would be kept and the new object's lists delivered to the old block. It cannot detect the one case the
  identity exists for.
- The removal notifications (measured above on macOS and 6.1.3): they name a destination, a source and an entity, never a port or a
  client, and they go to a client's notify proc on that client's run loop; the library would need a client of its own and a thread
  running a loop, and would still not cover the objects whose blocks it holds most often.
- Intercepting the library's own dispose entries: the entries are the release's exports (MIDIEndpointDispose, MIDIPortDispose,
  MIDIClientDispose); the port cannot interpose them (facts/VideoToolbox/PixelRotationSession.md).

## The receive block's lifetime and the locks of the send path (2026-10-10)

- A port or destination keeps the block it was given as one copy, made when the object is made, and counts references to its
  receive side: the owned row holds one, and each read callback, each in-process send and each queued delivery holds one for as
  long as it calls the block. The block is called with no retain of its own, so an application's sender thread (often an audio or
  MIDI thread with no autorelease pool) leaves nothing in a pool. Before, the lookup handed the block out through an ARC
  out-parameter: armv7 -O2 of the lookup called objc_retainBlock and objc_autorelease on every send, and the read callback called
  objc_retainBlock and objc_release on every callback (counted in the run folder of the band, asm-c3-before.txt and
  asm-c3-after.txt: the calls of the send, delivery and read paths are 0 after).
- The owned table's lock is held for the search and the reference alone, and the search reads no property: a send to a destination
  the library made takes its port and queues the list, and makes no call into the release (Round 6; before it, the send read the
  object's stamp, a round trip to the server, on the sender's thread). The owner check is made on the delivery thread, right before
  the block is called (see "Deliveries to a destination the library made" below).
- The 1.0 route state of an endpoint is a route object of its own, found by a binary search of the table of routes (sorted by the
  endpoint reference). The table's lock is held for the search and the reference alone; the route's own lock is held while its list
  is translated, so two endpoints translate in parallel, and two lists of one endpoint keep the order of their 1.0 state. A route
  is dropped when a row is made for its reference (its state is the old object's), and a route whose endpoint is gone is swept.

## Deliveries to a destination the library made (Round 6, 2026-10-10)

- A send to a destination the library made (its row is found by a binary search of the owned table) queues the list: one allocation
  (the delivery, with the list in it), appended to one FIFO under its own lock. A drain runs on the serial queue
  charon.in-process-delivery, one at a time, and takes the deliveries in the order they were queued.
- A drain pass delivers at most 16 deliveries and runs at most 1 ms (the delivery that crosses 1 ms is the last of the pass); the next
  pass is scheduled while deliveries remain. Each delivery checks its object once, right before its block is called
  (charon_object_check, one property read of CHARON_OWNER_KEY at CharonMIDIPorts.m:321, about 18 us per call on the host: 18037 ns live
  and 18041 ns disposed in the same-slot run of Round 8; the five candidate reads of that run were 17.4 to 18.2 us); no check is carried over from the delivery before it
  (Round 8: before, consecutive deliveries to one row shared a check per pass). The check is the only property read of a delivery.
  The gap between a delivery's check and its call is not bounded by the code (see "Window of the check" below).
- What a delivery does with the check: a live object gets its block called; a disposed object (paramErr) gets nothing, as the release
  delivers nothing to a disposed destination; a reference the release gave to another object (the stamp answers another value or
  none) takes the release's route instead: a 2.0 list is converted to MIDI 1.0 and sent with MIDISend through the port the sender
  gave; a UMP request's words take the release's sysex route (CharonMIDIUMPReleaseSend), as a UMP send to any other destination does.
- A UMP sysex sent to a release destination (Round 9): the words are converted in stack storage and the bytes are copied once into the
  block that holds the send's request and its data, which the release's completion frees. That is one allocation per release (the
  previous library made two: the conversion's 64-byte buffer, kept as the data, and the send struct). The release's sysex send is
  asynchronous, so the block cannot be on the stack. Host only, one release with a stand-in that completes the send inside the call
  (bench-ump.m, medians of five interleaved rounds): 41.2 ns before, 27.1 ns after. The A5 of the iPhone 4S and the iPad 2 are not measured.
- Measured on the macOS 27.0.1 host with a benchmark program (bench.m in the run folder v-midifix7, built against the library's folder;
  not committed). The sender's cost of a 2.0 send to a library destination, against Apple's
  MIDISendEventList to a 1.0 destination in the same run (not like for like: Apple's send converts to 1.0 and hands it to the release,
  the library's queues the list). Before Round 6: 24313 ns against 81 ns (ratio 302) with one owned row, 20461 against 81 (253) with
  64, and 20067 against 77 (260) with 1024. After (the final tree, measured 2026-10-10 18:38): 24 ns against 55 (0.44) with one row,
  32 against 86 (0.37) with 64, and 42 against 91 (0.46) with 1024. The delivery pipeline (first to last block call, per message,
  20000 messages): before 20009, 21716 and 20448 ns for one, 64 and 1024 rows; with the check once per run of deliveries (the tree before Round 8), 1162, 1157 and 1167 ns.
  With the check per delivery (Round 8, the tree of this round's last code commit, host only; bench.m's delivery pipeline, the median
  of three runs in each of three interleaved rounds): 19007, 18013 and 18011 ns per message for one, 64 and 1024 rows, about 53000 to
  55000 messages a second on the drain thread. The same bench with the check replaced by a live answer (a build for this measurement
  only, not committed) runs 178 ns per message at 64 and 1024 rows; its one-row figure is not valid (a reset race in bench.m: the span
  reads from the machine's boot), so it is not reported. The difference, about 17.8 us per delivery, is the check's read.
- The owned table is searched by reference: a binary search, no allocation and no divide. The 1.0 route's cost with owned rows (a
  2.0 note to a 1.0 release destination, not this library's; Apple's MIDISendEventList in the same run in brackets): before, 116 ns at
  one row (81), 99 ns at 64 (81), 585 ns at 1024 (77), a ratio of 7.56 at 1024; after (the final tree), 125 ns at one row (55), 88 ns
  at 64 (86), 155 ns at 1024 (91). The ratio is noisy between runs (1.02 to 2.29 in the final run; an earlier run of the tree before
  its last edit gave 1.52, 1.46 and 1.79), so the absolute cost is the figure: it does not grow with the rows as before.
  Round 9 (M2, host only): a 2.0 send to a 1.0 row of this library no longer retains and releases the row's port (charon_destination_port
  with its twoOnly flag; the lock order is in the crutches register). Five interleaved rounds per row count (run folder v-midifix9/m2,
  analysis.txt): the library's send 103 ns before and 118 ns after at one row, 147 and 115 at 64, 134 and 118 at 1024, against Apple's
  MIDISendEventList to a 1.0 release destination at 59 to 103 ns. The ratio medians before and after: 1.83 and 1.73, 1.35 and 1.12,
  1.62 and 1.26 at one, 64 and 1024 rows. The paired differences per round have medians of +15, -29 and -23 ns against a spread of tens
  to hundreds of ns, so the change has no measurable effect on this host. F3 stays PARTLY: the ratio at one row is above 1.5.
  Round 8 (host only, interleaved: four variants of the tree, five rounds per row count, medians of the five rounds): the route 106,
  156 and 132 ns against Apple's 56, 88 and 91 (ratios 1.89, 1.77 and 1.45 at one, 64 and 1024 rows). The release's own legacy
  MIDISend of the same one note costs 62, 92 and 102 ns in the same rounds; the library's own work, with that call replaced by a
  no-op, costs 24, 26 and 31 ns. The variants without the owned-row lookup or without the route's retain moved the medians by -46 to
  +23 ns with no consistent sign, against a spread of 38 to 118 ns across the rounds of one variant: neither is shown to cost time,
  and neither was removed. Apple's MIDISendEventList is not a 6.1.3 comparison: the release of iOS 6.1.3 has no MIDISendEventList (the
  library provides it, MIDIProtocol14.m), so the route calls the legacy MIDISend.
- The sweep reads a window of the owned table and of the routes at each creation, as above. A process that makes no more objects keeps
  its stale rows and their blocks until the next creation: the sweep runs only when an object is made.

## What the hot paths cost on a 4S (2026-10-10)

Counted, not timed: the library makes these calls, and the counts are of calls, which a host run measures exactly
(tests/backports/host/coremidi/allocations.m, run by run.sh; the run folder keeps allocations-start.out, allocations-before.out
and allocations-after.out). No time is stated: the host is not an A5, and the iPad 2 (A5) that could time them was not used for
this.

| Operation | malloc, calloc and realloc calls of the library, at the start of the band / before this change / after |
| --- | --- |
| a read callback of three short packets from a source the port has seen | 2 / 2 / 0 |
| the first list of a new source (its parser is made) | 3 / 3 / 1 |
| a read callback of sixty packets (does not fit the stack storage) | 2 / 2 / 1 |
| a short 2.0 list sent to a release endpoint | 2 / 2 / 0 |
| the first send to an endpoint (its selection state is made) | 3 / 3 / 1 (Round 6: 2 for the process's first endpoint, the route and the table's first growth; 1 for each later endpoint, its route) |
| a list sent to a destination the library made (the delivery's one allocation) | 1 / 1 / 1, and no property read on the sender's thread (Round 6 and 8; the owner check is the drain's, one per delivery, right before its call) |

- The read callback and the send build their list, their words and their bytes in stack storage (512 bytes for the list, 128
  bytes, 32 words), and move to the heap only when a list does not fit it. The delivery to the library's own destination must
  outlive the call, so it is one heap allocation (the port reference and the list), and the queue's own continuation, which
  libdispatch keeps, is not counted. The copy of the block a port or destination keeps is the framework's and is made once when
  the object is made.
- CharonMIDIUp32From7 is written in 32-bit arithmetic: `0x80000000 + d * 34087042 + (2d + 63) / 126` with `d = x - 64`, which is
  the 64-bit rule because 2^32 = 126 * 34087042 + 4. armv7 -O2 of CharonCoreMIDI.c at iOS 6.0 against the 16.4 SDK had `___udivdi3`
  among its undefined symbols (a libgcc call, with no hardware 64-bit divide on the A5) and has not now (core-undefined-before.txt
  and core-undefined-after.txt). No object of the library calls a 64-bit divide or modulo (scanned: every CoreMIDI source,
  nm -u, no `divdi`, `moddi`, `udivmod`). differential.m checks the new rule against the 64-bit rule at all 128 inputs, and the
  oracle rows (batch-up.txt) check it against the measured macOS answers at all 128.
- CoreBluetooth is not linked. MIDIBluetooth16.m's undefined symbols had `_OBJC_CLASS_$_CBCentralManager` and
  `_OBJC_CLASS_$_CBUUID`, and have none now: the framework is opened with dlopen the first time the central is used, and the
  classes are found with objc_getClass. The line that linked it is gone from modules/apple/backports.lua. A process that never
  activates the central (and the two driver functions are not exported, so none does) loads no CoreBluetooth image for this
  library. The release's own libraries may have loaded it already; this library no longer causes it.
- The sweep of the owned table is incremental. A creation reads a window of 8 rows of the owned table and 8 routes
  (charon_sweep, CharonMIDIPorts.m), from where the last creation stopped, with no lock held during the reads. So a creation
  makes at most 16 property reads however many objects the process holds, where it made one for every row and every state;
  a table of N rows is walked in N / 8 creations. The cost of that is a delay: a stale row's block is kept for up to N / 8
  creations, and not released at the next one. It is a bounded delay in memory and never an answer: a send checks its own
  destination when it is made. The release's removal notification (the other way to learn of a dispose, above) was not used:
  it covers destinations and sources only, it needs a client of the library's own and a running main run loop, and it brings
  every setup change of the process to that client.
- A creation that finds a sweep running on another thread does not wait for it: the next creation looks at the window.

## Does the release's dispose wait for a running read procedure? (measured 2026-10-10)

Probe: oracle/disposewait.h (the host program oracle/disposewait.m and the 6.1.3 application, tests/backports/emulate/coremidi/app/main.m,
run the same code). A read procedure announces that it is running and then waits up to 5 s; another thread disposes the object and
the probe says whether the dispose came back within 1.5 s while the procedure was still running.

| Object | macOS 27.0.1 (oracle/disposewait-macos.txt) | emulated iPhone 4S at 6.1.3 (run folder of the band, app-r8b.out) |
| --- | --- | --- |
| destination (MIDIEndpointDispose, list sent with MIDISend) | not within 1.5 s; returned after the procedure did | the same |
| input port (MIDIPortDispose, list from MIDIReceived on a connected source) | the same | the same |

What the library's lifetime rule does with that. A row is freed by the sweep only after the stamp read (charon_object_check) says
the object is gone or answers another stamp, and the read says so only once the dispose has come back, which (measured above)
is after any read procedure that was running has returned. And the release gives no list to a disposed destination (a send to it delivers 0 calls, above). So the sweep's free of a row
does not overlap a read procedure of that object; the reference the read holds (charon_port_retain) is for the paths the dispose does
not order: a queued in-process delivery, and a send that found the row before the sweep removed it.

A queued in-process delivery is checked right before its block is called (Round 6; per delivery since Round 8, "Deliveries to a
destination the library made" above): a destination disposed before the check runs nothing, and a reference given to another object
takes the release's route. Measured on the host (tests/backports/host/coremidi/delivery.m; macOS 27.0.1, Apple M4 Pro): test E (one call
held inside its block, two deliveries queued behind it, the dispose issued and returned while it is held) runs neither queued delivery
after the dispose returned, where the library before Round 6 ran both (2 of 2); the release's own destination, the control, runs none
after its dispose either. In the hold rounds (200 rounds of that shape, 31 deliveries queued behind the held call) 0 calls begin after
the dispose returned, in each of 24 runs of the test; the check-less mutant of Round 8 runs 6200 of 6400 after it.

What remains is the gap between a delivery's check and its call. The code does not bound it: the check's reply and the drain thread's
scheduling lie inside the gap, so a dispose that returns in it is followed by the call. The race of delivery.m measures the gap: 200
trials of 32 fast messages, the dispose issued once the first call has begun, nothing held. Round 8: in 24 runs of the test (the host's
load was not recorded), the calls begun after the dispose returned in a run were 0 (6 runs) or 1 to 10 (18 runs; median 2 over the 24),
and the latest such call began 0.003 to 0.069 ms after its dispose (median 0.011 ms over the 18 runs with late calls). Round 9: 20 valid
runs of the tip, the 1-minute load average before each run 10.9 to 13.8 (no run below 3, so no quiet band was taken in this round). The
calls begun after the dispose returned per run: 0 (3 runs), otherwise 1 to 53 (median 17.5 over the 20). The latest such call began
0.011 to 2.167 ms after its dispose (median 0.036 ms over the 17 runs with late calls). Five of the 25 attempts were refused by the release
at MIDIClientCreate (status -304, before any assertion; four in the loop, one in the retry) and are not counted; the run folder keeps their logs. The count and the lateness
move with the load the host has. They are a property of scheduling, not a figure, and the code gives no bound for them. The guarantee
that a dispose which has returned is seen by every later check is measured for destinations only (the queue holds no other object). Round 6 stated "1 ms plus one call" as a bound; the code
does not give it, and one of 19 runs of the Round 7 tip (the check made once per run of deliveries; review r5) showed a call 3.240 ms after its dispose.
The library does not close the gap: a dispose does not wait for a block that is queued but not called (the release's dispose waits for
its own running read procedure; the library's block is not the release's). What is not measured: a dispose called from inside the
object's own block, more than one object at a time, and the A5 CPU of the iPhone 4S and the iPad 2 (every figure here is the host's).

## What the owner stamp costs a client (measured 2026-10-10)

The stamp (`charon.owner`, CharonMIDIPorts.m, charon_own) is a property written on each object the library owns. The release posts
kMIDIMsgPropertyChanged for a property written on an object to every client with a notify proc. Measured by oracle/stamp.h, which makes
a destination, a source, an input port, an output port and a client in one process and writes the stamp on each: one notification
for each stamped object, five in all, with the object type (3 destination, 2 source, -1 input port, output port and client) and the
property name 'charon.owner' (macOS 27.0.1, oracle/stamp-macos.txt: 7 notifications, those five and the two the probe's own UniqueID
writes make; the emulated 6.1.3, app-r8b.out: 9, the same seven and two more that the application's own earlier steps cause
through the library: a 'protocol' write and a stamp, both before the probe's objects). So a client with a notify proc, on either release, sees one extra
property-changed notification with the library's own key name for each object the library takes a row for. It is the price of an
identity an application cannot disturb; the alternative that was measured against it, the UniqueID, is the creator's to set (the
decision above).
