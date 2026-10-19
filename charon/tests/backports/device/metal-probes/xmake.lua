set_project("metalprobes")
set_version("0.1.0")
-- The command queue and command buffer probe and the buffer probe, run on the emulated iPhone3,1 6.1.3 guest
-- against the answers Apple's own Metal gave on this host (tests/backports/device/*/host-expectations.txt).
--
-- WHY ONE PROJECT WITH TWO TARGETS, like metalchain-probe: a case has to be something `xmake emulate install` can put
-- in the image, which means a target with a control file and a daemon rule, not a source file in tests/backports/device.
--
-- THE PORT'S METAL SOURCES ARE COMPILED IN, the same as metalchain-probe: every packages/a/apple-backports/Metal/*.m
-- goes into each target, and the reason is that the library form of the package does not resolve from this project
-- (see metalchain-probe/xmake.lua for the measured error).
--
-- THE LIBRARY PROBE IS NOT HERE. It builds its library from source, which the port refuses by design; its port run
-- needs a translated library from a metallib file, which this tree cannot make yet (tools/air2es, see
-- facts/Metal/LibraryDescriptors.md).
local root = path.absolute(os.getenv("METALPROBES_ROOT") or path.join(os.scriptdir(), "../../../.."))
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
local minimum = os.getenv("METALPROBES_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- THE GENERATED PROTOCOL HEADER. CharonMetalProtocols.h is written at build time by tools/gen (protocolheaders, the
-- same command the package's build runs), into the framework's .gen folder, and the Metal sources import it by its
-- bare name. The package's own build puts that folder on the path; a project that compiles Metal/*.m itself has to do
-- both steps, or the compile dies on `'CharonMetalProtocols.h' file not found` (measured 2026-10-17).
local generated = path.join(root, "packages/a/apple-backports/.gen/Metal")

local function probe(name, source, control)
    target(name)
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/device", source))
        add_files(path.join(root, "packages/a/apple-backports/Metal/*.m"))
        add_frameworks("Foundation", "QuartzCore", "OpenGLES", "CoreGraphics")
        add_includedirs(generated)
        add_mflags("-fobjc-arc")
        add_ldflags("-fobjc-arc", {force = true})
        set_values("charon.control", control)
        before_build(function (target)
            os.runv(os.programfile(), {"l", path.join(root, "tools", "gen.lua"), "protocolheaders", "--tree", root, "--framework", "Metal"})
        end)
end

probe("commandbuffer-probe", "commandbuffer-probe/commandbuffer.m", "control-commandbuffer")
probe("buffer-probe", "buffer-probe/buffer.m", "control-buffer")
