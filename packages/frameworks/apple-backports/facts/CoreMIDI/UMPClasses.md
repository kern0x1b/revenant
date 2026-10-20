# MIDI-UMP and MIDI-CI device classes of iOS 18: what each answers

Nine classes of the iOS 18 surface are implemented in `CoreMIDI/MIDIUMP18.m` over the declarations in `CoreMIDI/RevenantMIDIUMP18.h`
(transcribed from the 26.2 headers; the 16.4 SDK has none of them). Measured on macOS on 2026-10-09 by
`tests/backports/host/coremidi/oracle/umpclasses.m` and `umpclasses2.m` (recorded in `umpclasses-macos.txt` and
`umpclasses2-macos.txt`); differential-ump.m holds the port to the answers below.

Measured and held to the port:

- MIDICIDeviceManager.sharedInstance.discoveredCIDevices has no device: 0 on the measured host.
- MIDIUMPEndpointManager.sharedInstance.UMPEndpoints has no endpoint before one is made: 0.
- A MIDIUMPMutableEndpoint is made with a name, a device info, a product instance ID, a protocol and a destination callback.
  Made with protocol 2.0 it has both ends (a destination and a source), is disabled, and reports protocol 2.0 and its name.
  The endpoint manager lists it while it is disabled: 1.
- setName: answers YES and changes the name (measured on macOS); the port also sets the release's kMIDIPropertyName of both
  ends, which the release reads back (differential-ump.m). setEnabled:YES answers YES and enables, which is the state the
  port keeps.
- A disabled endpoint's destination still delivers to its block, as an enabled one does: 1 call in each of the three sends of
  oracle/umpgate.m (never enabled, enabled, after setEnabled:NO; umpgate-macos.txt). The port delivers the same way, so the
  enabled state is reported and does not gate delivery, as on macOS.
- The function blocks of one registration are numbered from 1 in the order given: three blocks answer 1, 2, 3 (umpgate-macos.txt).
  The port numbers them the same way (differential-ump.m).
- registerFunctionBlocks:markAsStatic:error: answers YES, and the endpoint's functionBlocks then lists the block (count 1).
  hasStaticFunctionBlocks answers the argument: NO for markAsStatic:NO, YES for markAsStatic:YES (oracle/umpstatic.m,
  umpstatic-macos.txt); the port answers the argument the registration gave.
- hasJRTSReceiveCapability and hasJRTSTransmitCapability answer NO for an endpoint an application makes, before and after a
  registration with either static value (umpstatic-macos.txt: 0 and 0 each time). Both are read-only properties in the 26.2
  header, and nothing in CoreMIDI's headers sets them, so the port answers NO for its own endpoints, which are all virtual.
- The three UMP property keys (`active group bitmap`, `ump endpoint`, `associated endpoint`) on an endpoint of the emulated 6.1.3
  release read -10835, property not present (the probe, tests/backports/emulate/coremidi/app/main.m): the release has no such
  property of its own, as a virtual endpoint on macOS has none until it is set (facts/CoreMIDI/Constants.md). The port does not
  set them on its endpoints.
- A MIDIUMPMutableFunctionBlock is made for each group, direction and stream value tried (the groups 0 + 17 and 15 + 2 included,
  a total of 0 included): the header's validation is not what macOS does here. Its name, first group, groups and enabled state
  are the ones given.
- A function block not registered to an endpoint answers NO to setEnabled:, setName: and reconfigureWithFirstGroup:, as macOS does.
- MIDI2DeviceInfo keeps its manufacturer ID, family, model and revision, as given.

Measured, not reproduced by a class that the port cannot reach:

- MIDICIDevice and MIDIUMPCIProfile describe a device that a MIDI-CI transport discovers. The port has no transport, so no
  such object is ever made; the classes exist, answer what a device without these properties answers (no profile, no
  supported capability), and are never returned.

Choices not measured:

- A function block registered to an endpoint answers its setters YES; the registered case was not measured on macOS.
- An endpoint made with protocol 1.0 has one end of each kind as made with 2.0; only the protocol 2.0 case was measured.
- The protocol outside 1.0 and 2.0 answers nil, as the endpoint's initialiser does not accept it on macOS either (not
  measured; the port's choice).
- The endpoints the manager lists are kept for the life of the process and are never disposed: a bounded leak, logged in
  coordination/crutches.md.

Not implemented: a MIDI-CI discovery (the MIDICIDeviceManager's and the old discovery manager's handlers), which needs the MIDI-CI
transport and is described in facts/CoreMIDI/MIDICI.md.
