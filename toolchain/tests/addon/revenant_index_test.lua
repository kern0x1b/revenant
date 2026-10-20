import("fixtures")

function failures(opts)
    local driver = opts.driver or path.join(opts.modules, "..", "tools")
    local index = import("package-index", {rootdir = driver, anonymous = true})
    local scratch = opts.scratch or fixtures.scratch()
    local found = {}
    local counter = 0

    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local function tree(files)
        counter = counter + 1
        local root = path.join(scratch, "index-" .. counter, "packages")
        for relative, text in pairs(files) do
            local target = path.join(root, relative)
            if text then
                os.mkdir(path.directory(target))
                io.writefile(target, text)
            else
                os.mkdir(target)
            end
        end
        return root
    end

    local function expect(files, want, message, table_groups)
        local got = index.index_findings(tree(files), table_groups or {libraries = {"xz"}})
        table.sort(want)
        check(table.concat(got, "\n") == table.concat(want, "\n"), message .. ": got [" .. table.concat(got, "; ") .. "]")
    end

    expect({["libraries/xz/xmake.lua"] = 'package("xz")\n'}, {}, "a folder of its group whose xmake.lua declares its own name must pass")

    expect({["libraries/quicly"] = false}, {"quicly has no xmake.lua, so the index serves no version of it"},
           "an empty folder must be refused, naming it", {libraries = {"quicly"}})

    expect({["build-tools/swift/xmake.lua"] = 'package("swift-runtime")\n'},
           {"swift declares package(swift-runtime), not swift"},
           "a package declared under another name must be refused, naming both", {["build-tools"] = {"swift"}})

    expect({["build-tools/zlib/xmake.lua"] = 'package("zlib")\n'},
           {"zlib is filed under build-tools, the table puts it under libraries"},
           "a package filed under the wrong group must be refused", {libraries = {"zlib"}, ["build-tools"] = {}})

    expect({["x/xz/xmake.lua"] = 'package("xz")\n'},
           {"x is not a group; the groups are libraries", "xz is filed under x, the table puts it under libraries"},
           "a letter folder must be refused")

    expect({["libraries/xz/xmake.lua"] = 'package("xz")\n', ["libraries/lz4/xmake.lua"] = 'package("lz4")\n'},
           {"lz4 is in no group of the table"}, "a package the table does not name must be refused")

    expect({["libraries/xz/xmake.lua"] = 'package("xz")\n', ["emulator/xz/xmake.lua"] = 'package("xz")\n'},
           {"emulator is not a group; the groups are libraries", "xz is filed under both emulator and libraries",
            "xz is filed under emulator, the table puts it under libraries"},
           "a package in two groups must be refused, naming both")

    expect({}, {"the table puts xz under libraries, and there is no folder of it"},
           "a package of the table with no folder must be refused")

    expect({["libraries/monocypher/xmake.lua"] = "-- none yet\n"}, {"monocypher declares no package(...)"},
           "an xmake.lua with no package call must be refused", {libraries = {"monocypher"}})

    expect({["libraries/xz/xmake.lua"] = 'package("xz")\n', ["libraries/xz/patches/a.patch"] = "x\n"}, {},
           "files beside the xmake.lua must not matter")

    local tree_found = index.layout_findings(path.join(opts.modules, "..", "..", "packages"))
    check(#tree_found == 0, "the toolchain's own packages must be filed by the table: " .. table.concat(tree_found, "; "))

    if not opts.scratch then
        os.tryrm(scratch)
    end
    return found
end
