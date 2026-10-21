local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/symbol_check.lua [--pin] [BUILD]
  compares the symbols JavaScriptCore, WebCore and WebKitLegacy import and the Objective-C classes they
  export with carry-symbols.txt; --pin makes this build the new baseline. BUILD is an engine build folder
  or a staged tree; the default is the stage of the system webkit-engine package.]]

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given, rest = tree.arguments({...}, {pin = "switch", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local symbols = tree.modules("symbols")
    local build = rest[1] and path.absolute(rest[1]) or path.join(tree.where("webkit-engine"), "stage")
    if given.pin then
        print("pinned %d symbols", symbols.write_pin(build))
        return
    end
    local new_imports, lost_classes = symbols.compare(build)
    for _, verdict in ipairs({{"new undefined symbols", " - iOS 6 may not have these", new_imports},
                              {"Objective-C classes no longer exported", "", lost_classes}}) do
        if #verdict[3] > 0 then
            print("FAIL  " .. verdict[1] .. verdict[2] .. ":")
            for _, entry in ipairs(verdict[3]) do
                print("        " .. entry)
            end
        else
            print("ok    no " .. verdict[1])
        end
    end
    if #new_imports > 0 or #lost_classes > 0 then
        raise("SYMBOLS CHANGED - check each against the device, then --pin")
    end
    print("symbols intact")
end
