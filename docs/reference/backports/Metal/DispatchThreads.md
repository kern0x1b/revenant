# Metal compute dispatch by threads per grid on iOS 6

`-[MTLComputeCommandEncoder dispatchThreads:threadsPerThreadgroup:]` is the iOS 11 member that dispatches a grid of
threads and lets the last group of an axis be smaller than the others. The backport declared a selector no SDK has,
`dispatchThreads:threadsPerGrid:`, so a call written against the SDK did not reach it and the lowering did not strip the
member's availability. The encoder (`frameworks/Backports/src/Metal/MTLComputeCommandEncoder8.m`) now implements the SDK's
selector, and `frameworks/Backports/tools/lowered-members.txt` lists it as a protocol member of
`MTLComputeCommandEncoder`.

## What it does

- The groups on an axis are the grid divided by the group size, rounded up (`RevenantMetalGroupCount` in
  `frameworks/Backports/src/Metal/RevenantMetalGrid.h`).
- The last group of an axis runs only the threads the grid has left (`RevenantMetalGroupExtent`), so no thread runs past
  the grid. `dispatchThreadgroups:threadsPerThreadgroup:` still runs whole groups.
- A kernel the port translated to the GPU runs the whole grid in one dispatch, as for `dispatchThreadgroups`.
- A dispatch with no pipeline, an unsized threadgroup block or an empty dimension is refused with a log line, as before.
  An empty grid runs nothing.

## Pipeline limits

`maxTotalThreadsPerThreadgroup` and `threadExecutionWidth` of the port's compute pipeline were the thread count a
dispatch had last set, which made both properties change under the caller. They are constants now
(`RevenantMetalMaxThreadsPerThreadgroup` is 128 and `RevenantMetalThreadExecutionWidth` is 32, in `RevenantMetal.h`),
so a caller that sizes its groups from them gets the same answer before and after a dispatch.

## Checked

- `frameworks/Backports/tests/Metal/grid_test.m` (host, `MetalBackports_grid_test`): 12 checks of the group count, the
  group extent and that the groups of ragged, odd and even grids cover exactly the grid. Its `--negative` run fails all 12.
- A Swift line of Telegram's `RoundVideoFrameProcessor.swift` that calls `dispatchThreads(_:threadsPerThreadgroup:)`
  typechecks at armv7 iOS 6.0 against the lowered SDK.

Not measured on a device: the dispatch itself. The grid arithmetic is what the host test covers.
