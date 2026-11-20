import("async.runjobs")

function main(llvmbin, sdk, limit, ...)
    local translate = import("translate", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local folders = {...}
    local host = {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", sdk, "-O0", "-w"}
    runjobs("objectsplit pair", function (index)
        local objects = translate.compile_lifted({llvmbin = llvmbin}, folders[index], host, tonumber(limit))
        io.writefile(path.join(folders[index], "objects.txt"), table.concat(objects, "\n") .. "\n")
    end, {total = #folders, comax = #folders})
end
