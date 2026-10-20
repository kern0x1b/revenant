local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local ENTRY = {"Swift", "SwiftUI", "SwiftUICore", "Foundation", "CoreFoundation", "Combine", "Observation", "CoreGraphics", "UIKit"}

local function surftool()
    local project = tree.root("Tests", "Surface")
    local build = tree.run("surface", "build")
    local envs = {XMAKE_CONFIGDIR = tree.run("surface", "config")}
    for _, argv in ipairs({{"f", "-P", project, "-o", build, "-y"}, {"build", "-P", project}}) do
        os.execv(os.programfile(), argv, {envs = envs})
    end
    local tool = path.join(build, "macosx", "arm64", "release", "surftool")
    if not os.isfile(tool) then
        raise("the build of %s left no surftool at %s", project, tool)
    end
    return tool
end

local function interfaces(sdk, modules)
    local found = {}
    for _, name in ipairs(modules) do
        local folders = os.dirs(path.join(sdk, "**", name .. ".swiftmodule"))
        table.sort(folders)
        if #folders == 0 then
            raise("the SDK at %s has no %s.swiftmodule", sdk, name)
        end
        local files = os.files(path.join(folders[1], "*.swiftinterface"))
        table.sort(files)
        table.join2(found, files)
    end
    return found
end

function main(...)
    local modules = #{...} > 0 and {...} or ENTRY
    local sdk = tree.sdk()
    local tool = surftool()
    local out = path.join(tree.run("api"), "apple-26-surface.tsv")
    local file = io.open(out, "w")
    os.execv(tool, table.join({sdk}, interfaces(sdk, modules)), {stdout = file})
    file:close()
    print("%s written", out)
end
