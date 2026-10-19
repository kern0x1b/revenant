# MIDIDeviceNewEntity, as an application sees it

MIDIDeviceNewEntity (iOS 14) adds an entity to a device. An application cannot make a device: MIDIDeviceCreate takes a
driver interface, and with NULL it answers paramErr (-50), measured on macOS (oracle/newentity.m, newentity-macos.txt).
So the devices an application can name are the setup's own.

Measured on macOS: MIDIDeviceNewEntity with device 0 answers -50 and leaves the entity at 0 (oracle/newentity.m). With the
first device of the setup it answered noErr (oracle/newentity2.m, newentity2-macos.txt). That call changed the host's MIDI
setup: it added an entity "x" (protocol 1, no sources or destinations) to the device "Network".

Revert (2026-10-10): the entity was removed with MIDIDeviceRemoveEntity, the public call that undoes an add. The setup read
back with a read-only enumerator now equals the capture taken after the revert; the only difference from the capture taken
before it is the removed entity. No capture exists from before the probes, so the pre-probe state is inferred from the
probe's single mutating call. The Bluetooth driver's "activate all devices" flag has no baseline and is not reverted: a read-only
read of the host's MIDI preferences on 2026-10-10 gives 0 (the first report said 1, which was a misreading), and the value before
the probes is unknown. See coordination/wave-2026-10-03/v-midifix2-report.md, Round 3, "Host state".

Rule for every probe: no probe creates or edits a persistent host MIDI object (devices, entities, endpoints, setup
preferences). A probe may create virtual endpoints only if it disposes them in the same process. oracle/newentity2.m is
kept for the record and must not be run.

The port answers device 0 with paramErr and no entity, as macOS does. A device that exists is the release's own; the
entity is added by the release's MIDIDeviceAddEntity, and the port sets the protocol on the ENTITY (the property MIDIDeviceNewEntity
writes after MIDIDeviceAddEntity). The release's answer of each step is the answer of the call: a refused add is returned with no
entity, and an entity whose protocol the release refused is removed again with MIDIDeviceRemoveEntity (a removal that is refused
is logged) and returned as the refusal, with no entity (host/coremidi/entity.m, against stand-ins for the three release calls;
the release cannot be made to refuse the property, and an entity on the host is forbidden). Where macOS keeps the protocol of an entity, and whether its endpoints read it, is NOT measured:
the positive probe (oracle/newentity.m) died at MIDIDeviceCreate with -50, and an entity on the host is forbidden
(oracle/newentity2.m). So the endpoint-level claim is withdrawn; the entity-level write is the port's own choice and a
crutch (coordination/crutches.md). A protocol other than 1.0 and 2.0 answers paramErr; macOS was not measured for it.

On the emulated 6.1.3 the probe of tests/backports/emulate/coremidi/app/main.m (built with CHARCOREMIDI_PROBE=1) counts the
setup's devices and, where there is one, adds an entity of protocol 2.0, reads the protocol back and removes the entity. Measured:
the emulated setup has 1 device; MIDIDeviceNewEntity (protocol 2.0) answers noErr and gives an entity; the entity answers its
protocol property (the string key `protocol`) with 2, as written; MIDIDeviceRemoveEntity answers noErr. So the entity-level write
is accepted and read back by the release on 6.1.3. An application cannot make a device there either (MIDIDeviceCreate is
MIDIDriver.h's call and takes a driver). Whether the entity's endpoints take the protocol is not measured.
