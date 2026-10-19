# MTLCommandBufferDescriptor, iOS 14

Part of the Tier 2 Metal/MetalKit verdict: a plain descriptor for configuring a new command
buffer, real independently of any GPU driver.

## What the port does

`retainedReferences` defaults to `YES` as the header documents; `errorOptions` holds what is set.
`-copyWithZone:` copies both. `MTLCommandBufferEncoderInfoErrorKey`, the `userInfo` key the header
says carries per-encoder execution status when `MTLCommandBufferErrorOptionEncoderExecutionStatus`
is set, is carried as its own literal string alongside the descriptor that names it.

## What differs from the release

Nothing in this port reads `errorOptions` or ever populates `MTLCommandBufferEncoderInfoErrorKey`
in a command buffer error's `userInfo`: this port's `CharonMetalCommandBuffer` does not implement
per-encoder execution-status tracking, so the descriptor's option has nowhere to take effect yet.
The descriptor itself is real and correct; the tracking it can ask for is a separate, unbuilt gap,
named here rather than left implicit.
