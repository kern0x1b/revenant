# MIDI-CI: the classes of 12 to 18, and why no MIDI-CI device is ever seen

The MIDI Capability Inquiry classes come in two generations. The 1.x classes of iOS 12, 14 and 16 (MIDICIProfile,
MIDICIProfileState, MIDICISession (12); MIDICIDiscoveredNode, MIDICIDiscoveryManager, MIDICIResponder, and the protocol
MIDICIProfileResponderDelegate (14); MIDICIDeviceInfo (16, by the release-split tool)) are in `CoreMIDI/MIDICI12.m`,
`MIDICI14.m`, `MIDICI16.m` and `CoreMIDI/RevenantMIDICI.h`. The
device classes of iOS 18 are in `UMPClasses.md`.

## What was measured on macOS (2026-10-09, oracle/micicapability.m and umpclasses.m)

- MIDICIDeviceInfo is made with a real destination and manufacturer 3, family 2, model 2 and revision 4 bytes; it is nil with
  a 2-byte manufacturer, with a 1-byte revision, and with no destination.
- A MIDICIProfile made from its bytes alone is named from them when the first byte is 0x7E: "Standard Profile Bank 0x00
  Number 0x01, Version: 0x02 Level: 0x03" for the bytes 7E 00 01 02 03. The profile ID is the bytes.
- MIDICIDiscoveryManager.sharedInstance.discoverWithHandler: never calls its handler (0 calls in 6 seconds). macOS printed
  "Unable to create MIDI client (err = -10844)" and "Unable to discover MIDI capabilities": its MIDI-CI client is refused.
- MIDICIResponder made with no profile delegate is nil.
- MIDICIDeviceManager.sharedInstance.discoveredCIDevices and MIDIUMPEndpointManager.UMPEndpoints list nothing on the measured
  host before a client makes an endpoint.

## What the port does, and why no device is ever seen

Discovery is a MIDI-CI exchange of SysEx messages over the MIDI endpoints of the machine: an initiator asks every endpoint for
its capabilities, and the devices answer. A port has the endpoints the release gives it, and the release refuses the virtual
endpoints an application makes in the emulated 4S (kMIDINotPermitted, -10844: facts/CoreMIDI/CoreMIDI.md). Even where it
allows them, the MIDI-CI client macOS itself refuses (-10844 above). So the port has no MIDI-CI transport, and its discovery
handler is never called, its device manager lists no device, and its session and responder answer that they cannot send.

Those answers are the ones macOS gives on the measured host, where discovery is refused. They are not claimed to hold on a
machine where a MIDI-CI device answers: no such device was measured.

## Not implemented

- The discovery exchange itself (inquiry, reply, the MUID and endpoint messages). It needs a transport, which in turn needs the
  question in CoreMIDI.md answered first.
- MIDIUMPCIProfile and MIDICIDevice objects: they describe a discovered device, so they are never made here.
- The protocol MIDICIProfileResponderDelegate is declared and its methods are the responder's (the responder never calls them);
  it is not registered as a protocol row, since the protocol-header pipeline (tools/transcribe-protocols.py) is not run for it.

## The action stubs (round 3)

- The MI-CI actions that would do something on a transport are `inert` in the registry: discoverWithHandler (MIDICIDiscoveryManager),
  start, notifyProfile and sendProfile (MIDICIResponder and its delegate protocol), and enableProfile and disableProfile
  (MICISession). Each does nothing and answers NO or returns, and says once in the log that it has no MI-CI transport
  (revenant_ci_inert, MIDICI14.m). macOS refuses its own MIDI-CI client on the measured host and never calls the discovery handler
  (oracle/micicapability-macos.txt), so that no-op is the measured answer there.
- The getters of the MI-CI device, profile and manager classes (no profiles, zero MUID and counts, nil names, empty device lists)
  answer for a port that has no MI-CI device at all. Those rows stay `implemented`: the device lists measured empty on macOS
  (oracle/umpclasses2-macos.txt), and an object that is not there answers those values.
