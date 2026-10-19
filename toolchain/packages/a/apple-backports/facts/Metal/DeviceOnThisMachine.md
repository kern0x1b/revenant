# The machine these Metal host cases run on, and why a descriptor still needs no device

A dozen pages in this folder used to give, as the reason a host case creates no Metal device, that
`MTLCreateSystemDefaultDevice()` **hangs** on a machine with no GPU. Two of them said it was measured
hanging and killed. That was a claim about a machine. This page is the measurement of the machine, and
of the question the claim was standing in for.

## The measurement

```
sh tests/backports/host/metal-census/hostdevice.sh
```

```
does this machine have a Metal device?
  ok   MTLCreateSystemDefaultDevice() answers
       it is <AGXG16SDevice: 0x74ac450000>
    name = Apple M4 Pro, name "Apple M4 Pro"
       lowPower=0 headless=0 hasUnifiedMemory=1 maxThreadsPerThreadgroup=1024
  ok   the device makes a 4x4 RGBA8 texture
  ok   a texel written to that texture reads back unchanged, first and last
  ok   a fresh MTLRenderPipelineDescriptor answers with no device at all
  ok   its colour attachment array answers at index 0 with no device at all
hostdevice: 5 check(s), 0 failure(s)
the control: a Metal class of a name that does not exist
nil (right)
hostdevice: the machine has a Metal device, it works, and a descriptor needs none
```

So on this machine the call answers, in well under a second, and the device works: a texture is made,
written and read back, and the texels come back unchanged. **The hang is not a property of this
machine and the pages that said so were wrong about it.**

The control is there because it is the one the old claim never had: `ZZZNoSuchNameCharonR16` is asked
the way a class is asked and answers nil, so a machine on which the check answered "there is a device"
for anything would have passed.

## Why the descriptor families still create no device

**A descriptor asks a device nothing.** Every side of every descriptor comparison is
`[[X alloc] init]` and `init` on these classes sets their own defaults and reads no device - which the
last two lines of the run above show for `MTLRenderPipelineDescriptor` and its attachment array, with
no device created anywhere in that run.

That is the true reason, and it is why the descriptor cases (`descriptors.sh`, `descriptors16.sh`,
`counters.sh`, `rasterrate.sh`) create none: creating a device would add a dependency the thing under
test does not have. The hang was not the reason, and a case that gave up on the hang gave up on
nothing - but a case that gave up on "a descriptor asks a device nothing" would have given up on a
real wall, which is what makes the distinction worth a page.

## What this page does NOT retract

* **The port's own device is still not a host object.** `CharonMetalDevice` is an EAGL context over
  OpenGL ES 2.0 and the iPhone 4S and the iPad 2 are the machines it runs on; nothing here changes
  that, and no host case can stand in for it.
* **The port's own Metal objects still cannot be linked into a host case.** The seam every case in
  `tests/backports/host/metal-census/` uses - the port's class under another name, and Apple's device
  handed to the port's own initializer - is unchanged. `mdltexture.sh` is the case that uses the seam
  furthest: the port's loader, the port's format table and the port's refusals, over Apple's device.
* **What a real device does with the bytes is still the device test's.** A host case measures the
  logic; `facts/Metal/PixelFormats.md` is where the format support of the port's own device is
  measured.