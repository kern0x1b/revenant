import("async.runjobs")
import("deps")
import("install")

local languages = {
    [".c"] = {"clang", "c"}, [".m"] = {"clang", "objective-c"},
    [".cc"] = {"clang++", "c++"}, [".cpp"] = {"clang++", "c++"}, [".cxx"] = {"clang++", "c++"},
    [".mm"] = {"clang++", "objective-c++"}, [".s"] = {"clang", "assembler"}, [".S"] = {"clang", "assembler-with-cpp"}
}

local per_language = {c = "cflags", ["objective-c"] = "mflags", ["c++"] = "cxxflags", ["objective-c++"] = "mxxflags"}

function static(package, opt)
    local toolchain = assert(package:toolchains(), package:name() .. " is built for apple-ios without the apple-ios toolchain")[1]
    toolchain:load()
    local root = path.absolute(opt.sourcedir or os.curdir())
    local builddir = path.join(root, "build_charon")
    local common = table.join(table.wrap(toolchain:get("cxflags")), table.wrap(opt.flags))
    for _, folder in ipairs(table.wrap(opt.includedirs)) do
        table.insert(common, "-I" .. path.absolute(folder, root))
    end
    for _, define in ipairs(table.wrap(opt.defines)) do
        table.insert(common, "-D" .. define)
    end
    local from_deps = opt.deps and deps.flags(package, opt.deps ~= true and opt.deps or nil) or {cflags = {}, cxxflags = {}}
    table.join2(common, from_deps.cflags)
    local files = {}
    for _, pattern in ipairs(table.wrap(opt.files)) do
        local matched = os.files(path.join(root, pattern))
        if #matched == 0 then
            raise("%s compiles %s, which matches no file", package:name(), pattern)
        end
        table.join2(files, matched)
    end
    local objects = {}
    for index, file in ipairs(files) do
        objects[index] = path.join(builddir, path.relative(file, root):gsub("[/\\]", "_") .. ".o")
    end
    local clang = {clang = toolchain:tool("cc"), ["clang++"] = toolchain:tool("cxx")}
    os.mkdir(builddir)
    runjobs("compile " .. package:name(), function (index)
        local file = files[index]
        local language = languages[path.extension(file)]
        if not language then
            raise("%s compiles %s, and nothing says which language %s is", package:name(), file, path.extension(file))
        end
        local specific = table.wrap(opt[per_language[language[2]] or ""])
        local cxx = language[1] == "clang++" and from_deps.cxxflags or {}
        os.vrunv(clang[language[1]], table.join(common, cxx, specific, {"-c", file, "-o", objects[index]}),
                 {envs = {IPHONEOS_DEPLOYMENT_TARGET = toolchain:config("deployment")}})
    end, {total = #files, comax = os.default_njob()})
    local archive = path.join(package:installdir("lib"), "lib" .. (opt.name or package:name()) .. ".a")
    os.tryrm(archive)
    os.vrunv("xcrun", table.join({"libtool", "-static", "-o", archive}, objects))
    for _, pattern in ipairs(table.wrap(opt.headers)) do
        for _, header in ipairs(os.files(path.join(root, pattern))) do
            local destination = path.join(package:installdir("include"), opt.headers_prefix or "", path.relative(header, root))
            os.mkdir(path.directory(destination))
            os.vcp(header, destination)
        end
    end
    install.finish(package, {prune = opt.prune, licenses = opt.licenses, sourcedir = root})
    return archive
end
