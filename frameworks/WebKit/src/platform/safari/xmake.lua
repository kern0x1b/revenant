set_project("webkit-safari")
set_version("0.1.0")
add_rules("mode.release", "mode.debug")
set_defaultmode("release")
-- The loader carries the system variant of webkit-engine, the engine that replaces the phone's frameworks beneath Mobile
-- Safari. The root project holds one instance of webkit-engine, the prefixed variant, so the loader is its own project,
-- as the JavaScriptCore consumer is.
local root = os.getenv("REVENANT_ROOT") or path.join(os.scriptdir(), "../../../../..")
add_repositories("revenant " .. root)
add_addons("revenant", {sourcedir = path.join(root, "toolchain")})
add_requires("revenant@webkit-engine", {alias = "webkit-engine", configs = {variant = "system"}})
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
add_cxflags("-mcpu=cortex-a9", "-mfpu=neon")
add_defines("WEBKIT_IOS6_NO_READLINE")

-- The package paths are absolute: a relative one would resolve against this project, not frameworks/WebKit.
local webkit = path.join(os.scriptdir(), "../../..")
local version = "0.1.0"

local function packaged(target)
    target:set("values", "revenant.version", version)
    target:set("values", "revenant.control", path.join(webkit, "src", "packaging", "control"))
    target:set("values", "revenant.maintainer-scripts", path.join(webkit, "src", "packaging", "DEBIAN"))
    target:set("values", "revenant.licenses", path.join(webkit, "LICENSE"), path.join(webkit, "..", "..", "docs", "reference", "webkit", "third-party.md"))
end

target("RevSafari")
    add_rules("@addon/revenant/tweak")
    add_files("rev-safari-tweak.c")
    add_cflags("-Wall")
    set_optimize("faster")
    add_frameworks("CoreFoundation")
    add_packages("webkit-engine")
    set_values("tweak.filter", "rev-safari.plist")
    on_load(packaged)
    on_config(function (target)
        target:add("installfiles", path.join(target:pkg("webkit-engine"):installdir(), "stage", "(**)"), {prefixdir = "/"})
    end)
