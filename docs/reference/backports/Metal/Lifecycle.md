# Metal and OpenGL ES across the background on iOS 6

On the iPhone 4S (iOS 6.1.3) an app whose OpenGL ES context exists when it goes to the background is killed by
`backboardd` with `0xdead10cc` ("suspended with locked system files"). Telegram 13 hit this as soon as it was sent to
the background. The Backports Metal layer is an OpenGL ES 2.0 layer, so it inherited the problem.

## Where the lock is held

The lock is held while an `EAGLContext` exists, not while it is current. The `GL_VERTEX` and `GL_FRAGMENT` shaders and
the draws are not needed for the lock. The variant table below is the evidence: variant 4 creates a context and never
makes it current, and it is killed as variant 1 is, which makes a context current and clears it.

A context that is destroyed before the suspension does not hold the lock. Variant 3 destroys its context in
`DidEnterBackground` and survives. Variant 7 destroys its context in the foreground and survives. Variant 8 destroys the
context in the background and recreates it, with a program and a draw, in the foreground, and survives the next
background too. The context is recreated in the same process, so `WillEnterForeground` still fires and the pid stays the
same.

## The probe

`frameworks/Backports/tests/device_probe/gl_lock_main.m` is the target `GLLockProbe` in
`frameworks/Backports/xmake.lua`. It reads one character from `/var/revenant/gl-variant` at launch and runs that
variant. It logs its events to the syslog, which is captured with `./xmakew device -P . -s N log`.

| Variant | Launch | Background | Result on the iPhone 4S |
| --- | --- | --- | --- |
| 0 | nothing, no context | nothing | alive |
| 1 | context made current, cleared, `glFinish`, made nil; context kept | nothing | killed, `0xdead10cc` in the syslog |
| 2 | context made current, program built, drawn, made nil; context kept | nothing | killed (launchctl and `kill -0` only) |
| 3 | as 2 | context destroyed | alive |
| 4 | context created, never made current | nothing | killed, `0xdead10cc` in the syslog |
| 5 | context made current, program built, made nil; context kept | nothing | killed (launchctl and `kill -0` only) |
| 6 | as 2, but the context stays current | nothing | killed (launchctl and `kill -0` only) |
| 7 | as 2, context destroyed at once | nothing | alive |
| 8 | as 2 | context destroyed; in the foreground a new context is built, a program drawn | alive, through a second background |

Variants 2, 5 and 6 were judged by `launchctl list` and `kill -0` only; their syslog was not captured. Variants 1 and 4
were captured in the syslog.

## What the Backports layer does

`DidEnterBackground` (`RevenantMetalDevice revenantSuspend`):

1. Synchronise the surface-backed textures into their IOSurfaces (`RevenantMetalSynchroniseSurfaceTextures`).
2. `glFinish`, so every command issued before the background has completed.
3. Evict every resident object: each texture saves what it can (below) and deletes its GL names; each pipeline and the
   layer's framebuffers drop their GL names. Then `RevenantMetalDropPrograms` deletes the shared program cache.
4. Flush and release the CoreVideo texture cache.
5. Release the `EAGLContext`.

`WillEnterForeground` (`RevenantMetalDevice revenantResume`):

1. Create a new `EAGLContext` and increment the device generation. A drawable or command buffer from the earlier
   generation is stale.
2. Make the new context current and restore every resident object: textures are allocated again and filled, pipelines
   are linked again, layers rebuild their framebuffers on the next drawable request.

What each texture keeps across the background (`RevenantMetalResidencyPlanFor`, `RevenantMetalResidency.h`):

| Texture | Kept | How |
| --- | --- | --- |
| Plain colour, 8 bits per channel | yes | read back with `glReadPixels` into a CPU snapshot, written back on resume |
| IOSurface-backed | yes | the IOSurface holds the content, uploaded again on resume |
| CoreVideo-backed | yes | recreated from the image buffer through a new texture cache |
| Depth, stencil, float, half float | no | recreated empty; the first eviction logs this once, because OpenGL ES 2.0 cannot read them back |

Drawables and command buffers are not restored. A drawable made before the background is refused at `present` and logs
once. The frame after the return draws into a new drawable. The screen content is the last frame the system kept, until
the app draws again.

## Limits

- Encoders open across the background are not covered; their commands are refused while suspended.
- The snapshot is held in memory between the background and the return. Its size is the sum of the 8-bit colour textures.
- Performance of the suspension and the restore is not yet measured on the device.

## Checked

- `frameworks/Backports/tests/Metal/lifecycle_test.m` (host, `MetalBackports_lifecycle_test`): the depth, suspension and
  resumption counts. Its `--negative` run fails the checks it is written to fail.
- `frameworks/Backports/tests/Metal/residency_test.m` (host, `MetalBackports_residency_test`): the plan of each kind of
  texture and the generation test. Its `--negative` run also passes, because each check is written to be checked both ways.
- `frameworks/Backports/tests/device_probe/gl_lock_main.m` (target `GLLockProbe`): the variant table above, run on the
  iPhone 4S. The results are the ones in the table.
- `frameworks/Backports/tests/device_probe/lifecycle_main.m` (target `MetalLifecycleProbe`, run on the iPhone 4S, iOS 6.1.3):
  each foreground frame clears a private 64 by 64 BGRA8 texture, writes a 32 by 32 pattern into its corner, and reads the
  texture back. The first frame after the return compares the bytes with the last frame drawn before the background. The
  run: launched; 376 foreground frames; Home pressed at 6.4 s; the process was alive 15 s later (same process, no relaunch);
  returned at 22.8 s; `PIXELS match bytes=16384`; 120 frames drawn after the return with no dropped command buffer. The
  probe then exits by itself. The syslog carries one say-once line, "GL work requested while the app is in the background":
  the layer's `nextDrawable` acquires the device before it checks the suspension, which is harmless and unchanged.
