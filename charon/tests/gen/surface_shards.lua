-- The shards a fixture tree needs for the surface: surface_model.lua reads each framework's declaration shard (spec/<F>/declarations.tsv,
-- ObjC and C) and Swift shard (spec/<F>/swift.tsv), in the columns the dump writes. objc_row and swift_row build one row each, with the
-- side, type, params, message, declhash and value fixed; write puts a framework's rows under the tree's spec folder (a nested
-- framework's folder is spec/<Outer>/<Inner>). A fixture calls write(tree, fw, ...) once per framework it names.

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SNAP = "packages/a/apple-backports/spec"
local RELEASE = "26.2"
local OBJC_HEADER = "#libclang=fixture\tsdk=iPhoneOS" .. RELEASE .. "\tcolumns=kind,usr,container,name,side,type,params,attrs,availability,message,declhash,value\n"
local SWIFT_HEADER = "framework\tkind\tusr\tcontainer\tname\tside\ttype\tparams\tavailability\tmessage\tdeclhash\n"

-- One ObjC declaration row: the cells the shard's columns name, with the side, type, params, message and value fixed.
function objc_row(kind, usr, container, name, attrs, availability)
    return table.concat({kind, usr, container or "-", name or "", "-", "-", "-", attrs or "-", availability or "-", "-", "h", "-"}, "\t")
end

-- One Swift row of a framework's Swift shard, in the column order of the dump.
function swift_row(fw, kind, usr, container, name, availability)
    return table.concat({fw, "swift-" .. kind, usr, container or "-", name, "-", "-", "-", availability or "-", "-", "h"}, "\t")
end

-- Writes the framework's declaration shard from objc_rows and its Swift shard from swift_rows (either may be nil: no such shard).
function write(tree, fw, objc_rows, swift_rows)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local folder = path.join(tree, SNAP, fw)
    os.mkdir(folder)
    if objc_rows then
        assert(emit.file(path.join(folder, "declarations.tsv"), OBJC_HEADER .. table.concat(objc_rows, "\n") .. "\n"),
               "could not write the declaration shard of " .. fw)
    end
    if swift_rows then
        assert(emit.file(path.join(folder, "swift.tsv"), SWIFT_HEADER .. table.concat(swift_rows, "\n") .. "\n"),
               "could not write the Swift shard of " .. fw)
    end
end

-- Writes the framework's interface shard (spec/<F>/swiftinterface.tsv) from a Swift interface text, as swiftiface writes it: the text is
-- read by swift_interface.lua, so the fixture states each declaration's availability the way the SDK's text does.
function write_interface(tree, fw, text)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local swift_interface = import("gen.swift_interface", {rootdir = TOOLS, anonymous = true})
    local folder = path.join(tree, SNAP, fw)
    os.mkdir(folder)
    assert(emit.file(path.join(folder, "swiftinterface.tsv"), (swift_interface.shard_text(text, fw))),
           "could not write the interface shard of " .. fw)
end

-- The release the fixture shards are written for: the model refuses a declaration shard whose header names another release.
function release()
    return RELEASE
end
