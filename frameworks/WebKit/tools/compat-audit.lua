local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/compat-audit.lua --compat LIBRARY --engine-build DIR --icu DIR
  refuses a compat library whose stubs define a symbol the engine's objects or ICU already define;
  every build of the engine runs the same audit before it is staged.]]

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given = tree.arguments({...}, {compat = "value", ["engine-build"] = "value", icu = "value", help = "switch"})
    if given.help or not given.compat or not given["engine-build"] or not given.icu then
        print(USAGE)
        return
    end
    tree.modules("engine").verify_compat({compat = path.absolute(given.compat), build = path.absolute(given["engine-build"]),
                                         icu = path.absolute(given.icu)})
    print("audit: no stub of the compat library shadows a definition of the engine or ICU")
end
