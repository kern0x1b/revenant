local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SNAP = "packages/a/apple-backports/spec"
local RELEASE = "26.2"
local OBJC_HEADER = "#libclang=fixture\tsdk=iPhoneOS" .. RELEASE .. "\tcolumns=kind,usr,container,name,side,type,params,attrs,availability,message,declhash,value\n"
local SWIFT_HEADER = "framework\tkind\tusr\tcontainer\tname\tside\ttype\tparams\tavailability\tmessage\tdeclhash\n"

function objc_row(kind, usr, container, name, attrs, availability)
    return table.concat({kind, usr, container or "-", name or "", "-", "-", "-", attrs or "-", availability or "-", "-", "h", "-"}, "\t")
end

function swift_row(fw, kind, usr, container, name, availability)
    return table.concat({fw, "swift-" .. kind, usr, container or "-", name, "-", "-", "-", availability or "-", "-", "h"}, "\t")
end

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

function write_interface(tree, fw, text)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local swift_interface = import("gen.swift_interface", {rootdir = TOOLS, anonymous = true})
    local folder = path.join(tree, SNAP, fw)
    os.mkdir(folder)
    assert(emit.file(path.join(folder, "swiftinterface.tsv"), (swift_interface.shard_text(text, fw))),
           "could not write the interface shard of " .. fw)
end

function release()
    return RELEASE
end
