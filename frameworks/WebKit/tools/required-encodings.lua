local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/required-encodings.lua [--tree DIR]
  writes tests/host/required-encodings.txt from the ICU codec table of the patched WebKit tree,
  Source/WebCore/PAL/pal/text/TextCodecICU.cpp; the tree is the installed webkit package's unless
  --tree names one. Run it after moving the series to a newer upstream.]]

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given = tree.arguments({...}, {tree = "value", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local table_file = path.join(tree.engine_source(given.tree), "Source", "WebCore", "PAL", "pal", "text", "TextCodecICU.cpp")
    if not os.isfile(table_file) then
        raise("cannot read %s", table_file)
    end
    local names = {["UTF-8"] = true}
    local declared = 0
    local source = io.readfile(table_file)
    for _, macro in ipairs({"DECLARE_ENCODING_NAME", "DECLARE_ENCODING_NAME_NO_ALIASES"}) do
        for name in source:gmatch(macro .. "%(\"([^\"\n]+)\"") do
            names[name] = true
            declared = declared + 1
        end
    end
    if declared == 0 then
        raise("%s declares no encodings", table_file)
    end
    local sorted = table.orderkeys(names)
    local output = tree.member("tests", "host", "required-encodings.txt")
    io.writefile(output, table.concat(sorted, "\n") .. "\n")
    print("%d encodings -> %s", #sorted, output)
end
