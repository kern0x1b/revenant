set_project("emulateshims")
set_version("0.0.1")
local REVENANT = path.absolute(path.join(os.scriptdir(), "../../../.."))
add_repositories("revenant " .. (os.getenv("REVENANT_REPO") or REVENANT))
add_addons("revenant", {sourcedir = path.join(REVENANT, "toolchain")})
set_config("apple_minimum", "6.1.3")
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local SHIMS = "../../../src/apple-compat/src/"
local CASES = "../../addon/compat/"

target("at-race")
    add_rules("@addon/revenant/daemon")
    add_files(CASES .. "at-race.c", SHIMS .. "openat.c", SHIMS .. "fstatat.c", SHIMS .. "unlinkat.c")
    set_values("revenant.version", "1.0")
    set_values("revenant.control", "control-at-race")

target("named")
    add_rules("@addon/revenant/daemon")
    add_files(CASES .. "named.c", SHIMS .. "clock_gettime.c", SHIMS .. "openat.c", SHIMS .. "fstatat.c",
              SHIMS .. "unlinkat.c", SHIMS .. "fdopendir.c", SHIMS .. "linkat.c", SHIMS .. "mkdirat.c",
              SHIMS .. "renameat.c", SHIMS .. "renamex_np.c", SHIMS .. "fclonefileat.c",
              SHIMS .. "CCRandomGenerateBytes.c", SHIMS .. "sysdir_start_search_path_enumeration.c",
              SHIMS .. "sysdir_get_next_search_path_enumeration.c")
    set_values("revenant.version", "1.0")
    set_values("revenant.control", "control-named")

target("pinned-path")
    add_rules("@addon/revenant/daemon")
    add_files("pinned-path.c")
    set_values("revenant.version", "1.0")
    set_values("revenant.control", "control-pinned-path")
