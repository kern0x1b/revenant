task("emulate")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake emulate [options] install|run|launch|debug|log|shot|clean [arguments]",
        description = "Reach an emulated device: install the packages into its image, run a command in a fresh clone of it, launch an application through SpringBoard and snapshot it, debug the one that crashes, read what the run left, take its last frame, or remove what emulation left on disk. Every run first removes the images and root filesystems nothing has used for --prune-hours.",
        options = {
            {"d", "device", "kv", nil, "The device to emulate, e.g. iPhone3,1 (default: the first device of the configured architecture Shade emulates that runs the release)."},
            {"r", "release", "kv", nil, "The iOS release, the earliest firmware not older than it (default: apple_minimum)."},
            {"s", "seconds", "kv", "60", "How long the command run starts may take, or how long launch waits for SpringBoard to accept the launch and, with until-exit, how long the application may then run from the moment it is frontmost (guest seconds)."},
            {"t", "timeout", "kv", "900", "The wall-clock limit of a whole boot, after which the emulator is told to quit and then killed."},
            {"k", "keep", "k", nil, "Keep the root filesystem a run booted, beside its log, instead of removing it after the verdict."},
            {"a", "all", "k", nil, "With clean: every port's images and every golden image, not only this port's images."},
            {nil, "prune-hours", "kv", "24", "How long an image, an owner's images, or the root filesystem one run booted may sit unused before the next xmake emulate removes it."},
            {"n", "network", "kv", nil, "isolated, loopback or host (default: the emulate.network value of the project's targets, else isolated)."},
            {nil, "scale", "kv", nil, "How many host seconds one guest second takes, so the guest's own watchdogs and RPC deadlines see an emulator that is slower than the device (default: 10)."},
            {},
            {nil, "action", "v", nil, "install, run, launch, debug, log, shot or clean."},
            {nil, "arguments", "vs", nil, "The command run or debug executes; the bundle identifier launch starts, then its steps (tap X Y, drag X1 Y1 X2 Y2, home, until-exit; in points); the text log filters on; or the file shot writes."}
        }
    }
