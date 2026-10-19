# Debug groups and signposts on the encoders, iOS 8.0 and later

The protocol `MTLCommandEncoder` declares three members that name a span of commands for a capture:
`-pushDebugGroup:`, `-popDebugGroup` and `-insertDebugSignpost:`. The blit encoder has them from the
iOS 8.0 base file, and the compute and render encoders get them here, so the protocol is conformant on
all three encoder classes.

## What the port does

The three encoders and the command buffer share one helper, `Metal/CharonMetalDebugGroups.h`:

* **A push** adds the name to a stack the encoder keeps. A nil name is pushed as the empty string, so the
  stack never holds nil.
* **A pop** removes the innermost name. A pop with nothing open does not crash: the helper logs one line
  naming the class of the encoder, and returns.
* **A signpost** does nothing. A signpost is a string in a capture, and the port has no capture to put it
  in. Metal does not change behaviour on a signpost either, which the SDK header says.

The stack has no effect on the work. An encoder runs its commands as they are encoded, so a group is
only ever a name held until its pop; nothing is reordered, deferred or drawn differently inside a group.

## What is measured, and what is not

Nothing in this file is measured on the host. The host probe `tests/backports/device/commandbuffer-probe`
asks the command buffer's own debug groups and the blit path, not the encoder members of the compute and
render encoders, so the Metal answer for an unbalanced pop on an encoder is not recorded here. What Metal
does with one is the open question, and the port's log line is its own, not a copy of Metal's.

The three encoder files that carry the members compile for armv7 with the 16.4 SDK, and the light guard
passes with the protocol rows flipped. The members have not been run on the device.

## The members, and where each one is answered

| Member | Encoders | Port's answer |
| --- | --- | --- |
| `-pushDebugGroup:` | blit, compute, render | the name goes on the encoder's stack |
| `-popDebugGroup` | blit, compute, render | the innermost name is removed; an empty stack logs |
| `-insertDebugSignpost:` | blit, compute, render | returns; no effect |

The command buffer's own pair (`-pushDebugGroup:` and `-popDebugGroup` on `MTLCommandBuffer`, 11.0) is in
`facts/Metal/CommandBuffer.md`, and uses the same helper.
