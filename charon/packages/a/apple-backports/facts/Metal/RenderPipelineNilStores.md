# MTLRenderPipelineDescriptor: nil stores into the colour attachments and the linked functions

Measured on the macOS 26 host (`.agent-work/runs/mps-metal/rpd-nil/probe.m`, `linked.m`, `linked2.m`). The port's side is
`Metal/MTLRenderPipelineDescriptor8.m`, tested by `tests/backports/host/color-attachment-nil` (27 checks, all pass; the
mutant that allocates a new attachment instead of resetting the slot is red).

## Colour attachments (`colorAttachments[i]`)

- A nil store resets slot i IN PLACE: the object in the slot stays the same and its fields go back to the defaults a
  new attachment has (pixel format 0, blending off, write mask all, One/Zero factors, Add operations). Reading slot 0,
  which was never touched, gives the same defaults.
- A stored attachment is a copy: the object read back is not the object that was set, and its fields are the ones set.
- A copy of a descriptor carries each slot's fields.
- An index of 8 or more asserts, for both the store and the read: `attachmentIndex(8) must be < 8`, status 134.

## Linked functions (`vertexLinkedFunctions`, `fragmentLinkedFunctions`)

- A fresh descriptor answers an empty `MTLLinkedFunctions` for each stage, never nil, and the same object on every read.
- A stored object is a copy: the object read back is not the one set.
- A nil store gives a NEW empty object: not the one that was there before (so not an in-place reset, unlike the colour
  attachments), and not the fresh one.
- A copy of a descriptor answers a non-nil linked-functions object for each stage that is not the source's object. The
  contents of a copy with functions in it are not measured here: a `MTLFunction` needs a device, which the host run
  does not use for this check.

Not measured: whether the nil-store object keeps any property other than being empty (every linked-functions array is
empty in these probes), and any behaviour of the linked functions with a device.
