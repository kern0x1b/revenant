# Guest regression tests

Small armv7 programs that run inside the emulated device and check what only a
running guest shows: signal frames and fault delivery (`signals.c`), stale
translations after images are swapped or protections change (`remap.c`,
`remap_image.c`), and code rewritten through a second view of a page or from a
signal handler (`smc.c`).
`purgable.c` sets and reads back a memory object's
purgeable state word.
`remap_task.c` remaps memory into another task.
`sysctl_hw.c` reads the hw.* processor nodes and compares the counts with `host_info`.
`coreimage.m` draws with Core Image (an EAGL context, the CPU renderer, the
default renderer), including a Gaussian blur, and reads the pixels back.
`gles2.m` makes an OpenGL ES 2 context and checks `glReadPixels`, the compile and link of guest GLSL
ES shaders (a varying the two shaders declare differently does not link), and what they draw: uniforms,
interpolated varyings, `discard`, textures, blending.
`longrun.c` stays for a given number of seconds, for looking at what the
rest of a boot does meanwhile.

Each prints one line per check and exits with the number of failures.

    CC="clang -target armv7-apple-ios5.0 -miphoneos-version-min=5.0 -isysroot <iPhoneOS SDK>"
    $CC -mthumb -o signals signals.c
    $CC -o smc smc.c
    $CC -o remap remap.c
    $CC -o purgable purgable.c
    $CC -o remap_task remap_task.c
    $CC -o sysctl_hw sysctl_hw.c
    $CC -fobjc-arc -framework Foundation -framework CoreGraphics -framework CoreImage \
        -framework OpenGLES -o coreimage coreimage.m
    $CC -fobjc-arc -framework Foundation -framework OpenGLES -o gles2 gles2.m
    $CC -dynamiclib -DIMAGE_VALUE=1 -install_name /usr/local/lib/charon-remap-1.dylib -o charon-remap-1.dylib remap_image.c
    $CC -dynamiclib -DIMAGE_VALUE=2 -install_name /usr/local/lib/charon-remap-2.dylib -o charon-remap-2.dylib remap_image.c

Sign the results (ldid -S), put them in the rootfs of the device to boot, and
run them there as the test program of a boot; the install paths `remap.c` opens
are the `-install_name` values above.

A test started from `/etc/launchd.conf` must return from `launchctl` at once. launchctl waits for
each child that launchd.conf starts, and launchd loads the LaunchDaemons only after that, so a test
that blocks there keeps the Mach services it needs (for Core Image, com.apple.cvmsServ, which
launchd registers with its daemon's plist) from appearing. A test has to start after those services
are registered, as a device's applications do; the emulator runner does both: it forks, the parent
exits, the child calls `setsid`, and it starts the test once the services are registered.
