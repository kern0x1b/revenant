local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/symbol_check.lua [--pin] [BUILD]
  compares the symbols JavaScriptCore, WebCore and WebKitLegacy import and the Objective-C classes they
  export with carry-symbols.txt. An import the baseline does not list is accepted when the iOS 6.0 cache
  exports it from the library it names, and printed either way; --pin keeps the rejected imports and the
  classes of this build in the baseline, once each has been checked on the device. BUILD is an engine build folder
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
    symbols.verify(build)
    print("symbols intact")
end
