function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local isolate = import("isolate", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}

    if isolate.replace("a /x/p b /x/p/c", "/x/p", "/y") ~= "a /y b /y/c" then
        table.insert(found, "every occurrence of the old path must be rewritten")
    end
    if isolate.link_target("/x/p/build/rn", "/x/p", "/y") ~= "/y/build/rn" or isolate.link_target("/x/pp/rn", "/x/p", "/y") ~= nil then
        table.insert(found, "a link is retargeted only when it points into the old folder")
    end
    if isolate.folder_is_valid("/a/iso-test") or isolate.folder_is_valid("/a/Example") or not isolate.folder_is_valid("/a/iso") then
        table.insert(found, "a folder with test or Example in its path must be refused")
    end

    local files = {
        ["/c/old/React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm"] = "x",
        ["/c/old/Libraries/Image/RCTImageUtils.mm"] = "y",
        ["/c/new/React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm"] = 'initWithString:attributedString.string ?: @""',
        ["/c/new/Libraries/Image/RCTImageUtils.mm"] = "CGSize s = {(CGFloat)width.doubleValue};"
    }
    local picked = isolate.patched_sources({"/c/old", "/c/new"}, function (file) return files[file] end)
    if picked ~= "/c/new" then
        table.insert(found, "the install with all patches must be the one picked, got " .. tostring(picked))
    end

    local env = isolate.build_environment({folder = "/f", cache = "/k", checkout = "/w", engine = "/e", swiftui = "/s", backports = "/b", real = ""})
    if env.RN_EXPO_REAL ~= nil or env.RN_SRC ~= "/f/build/rn-src" or env.REVENANT_CACHE ~= "/k" or env.REVENANT_PREBUILT_ONLY ~= "1" then
        table.insert(found, "the environment must name the folder's own sources and cache, and an empty --real must set no RN_EXPO_REAL")
    end
    if isolate.build_environment({folder = "/f", real = "expo-battery"}).RN_EXPO_REAL ~= "expo-battery" then
        table.insert(found, "--real must reach RN_EXPO_REAL")
    end

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local project = path.join(base, "project")
    local folder = path.join(base, "copy")
    os.mkdir(path.join(project, "build", "rn-headers"))
    os.mkdir(path.join(project, "build", "ref", "paseo"))
    os.mkdir(path.join(project, "build", "iphoneos"))
    io.writefile(path.join(project, "xmake.lua"), "-- " .. project .. "\n")
    io.writefile(path.join(project, "build", "expo-core", "module.modulemap"), "header \"" .. project .. "/build/expo-core/a.h\"\n")
    io.writefile(path.join(project, "build", "iphoneos", "huge.o"), project)
    os.vrunv("ln", {"-s", path.join(project, "build", "expo-core", "module.modulemap"), path.join(project, "build", "rn-headers", "link.h")})
    local result = isolate.copy_project(project, folder)
    local resolved = os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
    if io.readfile(path.join(folder, "build", "expo-core", "module.modulemap")):find(project, 1, true) then
        table.insert(found, "a copied input must not name the original project")
    end
    if not io.readfile(path.join(folder, "xmake.lua")):find(folder, 1, true) then
        table.insert(found, "a copied project file must name the copy")
    end
    if os.isfile(path.join(folder, "build", "iphoneos", "huge.o")) then
        table.insert(found, "build products must not be copied")
    end
    if os.iorunv("readlink", {path.join(folder, "build", "rn-headers", "link.h")}):trim() ~= path.join(folder, "build", "expo-core", "module.modulemap") then
        table.insert(found, "a link into the original build must point into the copy")
    end
    if os.iorunv("readlink", {path.join(folder, "build", "ref")}):trim() ~= os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", path.join(project, "build", "ref")}):trim() then
        table.insert(found, "build/ref must stay a link to the shared read only tree")
    end
    if result.rewritten < 2 or resolved == "" then
        table.insert(found, "the copy must report the files it rewrote")
    end
    os.vrunv("rm", {"-rf", base})
    return found
end
