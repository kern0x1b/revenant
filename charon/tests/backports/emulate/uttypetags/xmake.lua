set_project("charonuttypetags")
set_version("0.0.1")
-- The guest side of the UTTypeCopyAllTagsWithClass differential (probe.m says what each line means). The host side is the
-- same probe.m built alone, against the host's function; run.sh does that. Configure, install and run with:
--   xmake f -p iphoneos -a armv7 -y
--   xmake emulate -d iPhone4,1 -r 6.1.3 install
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/uttypetags
--   xmake emulate -d iPhone4,1 -r 6.1.3 log
local root = os.getenv("CHARCALLS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
-- The addon the store holds and names active (see tests/backports/emulate/calls/xmake.lua).
add_addons("charon v0.8.13")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("uttypetags")
    add_rules("@addon/charon/daemon")
    add_files("probe.m")
    add_files("../../../../packages/a/apple-backports/UIKit/UTTypeAllTags8.m")
    add_files("../../../../packages/a/apple-backports/UIKit/UTTypeDynamic8.m")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation", "MobileCoreServices")
    set_values("charon.control", "control")
