# The default Metal device, iOS 8.0

`MTLCreateSystemDefaultDevice()` came in iOS 8.0 with Metal. It answers the device an
application draws with, and nil when the hardware has none; an application that offers
Metal with OpenGL ES behind it asks first, and takes the OpenGL ES path on nil.

Source: Metal of the arm64 shared cache of iOS 12.0 - `_MTLCreateSystemDefaultDevice` at
`0x183053fa8`, which runs a routine at `0x183054090` once, and answers the device the routine
leaves in a list it keeps.

## What it is

The list is filled once, from the graphics drivers of the machine, and the function answers
its first entry, or nil while the list is empty. Which driver puts a device on the list was not
read here; Metal runs on the graphics of the A7 and later, and the iPhone 4S and the iPad 2 that
run iOS 6 have the A5.

## Where iOS 6 differs

There is no Metal driver in iOS 6, and the graphics of the A4 and A5 could not have one: the iPhone 4S and the iPad 2 have a
PowerVR SGX 543, which runs OpenGL ES 2.0 and nothing later. The function answers the one device of the port, a device
whose commands run on OpenGL ES 2.0 in a context of its own. `supportsFeatureSet:` and `supportsFamily:` answer no for every set and
family, so an application that asks for a family before it uses one that needs it takes its own fallback.

What the graphics cannot do is refused where it is asked for, and RenderPath.md lists it: a compute pipeline answers an error, and a depth
and stencil state and the compute and blit encoders answer nil, with a line in the log. MetalKit is absent: an application that makes a
`MTKView` has none to make. The rows are in `registry/Metal/` and `registry/MetalKit/`.
