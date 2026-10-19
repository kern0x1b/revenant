function failures(opts)
    local index = import("index", {rootdir = opts.driver, anonymous = true})
    local found = {}
    local counter = 0

    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local function tree(files)
        counter = counter + 1
        local root = path.join(opts.scratch, "index-" .. counter, "packages")
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

    local function expect(files, want, message)
        local got = index.index_findings(tree(files))
        check(table.concat(got, "\n") == table.concat(want, "\n"), message .. ": got [" .. table.concat(got, "; ") .. "]")
    end

    expect({["x/xz/xmake.lua"] = 'package("xz")\n'}, {}, "a folder whose xmake.lua declares its own name must pass")

    expect({["q/quicly"] = false}, {"quicly has no xmake.lua, so the index serves no version of it"},
           "an empty folder must be refused, naming it")

    expect({["s/swift/xmake.lua"] = 'package("swift-runtime")\n'},
           {"swift declares package(swift-runtime), not swift"},
           "a package declared under another name must be refused, naming both")

    expect({["a/zlib/xmake.lua"] = 'package("zlib")\n'}, {"zlib is filed under a, not under z"},
           "a package filed under the wrong letter must be refused")

    expect({["m/monocypher/xmake.lua"] = "-- none yet\n"}, {"monocypher declares no package(...)"},
           "an xmake.lua with no package call must be refused")

    expect({["z/zlib/xmake.lua"] = 'package("zlib")\n', ["z/zlib/patches/a.patch"] = "x\n"}, {},
           "files beside the xmake.lua must not matter")

    return found
end
