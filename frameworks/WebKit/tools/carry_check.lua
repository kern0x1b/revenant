local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/carry_check.lua [--tree DIR] [--paths] [MANIFEST]
  checks that the patched WebKit tree still holds what this port depends on, against
  carry-manifest.txt or MANIFEST; the tree is the installed webkit package's unless --tree names one.
  --paths prints the engine paths the manifest reads and checks nothing.]]

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given, rest = tree.arguments({...}, {tree = "value", paths = "switch", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local carry = tree.modules("carry")
    local manifest = rest[1] and path.absolute(rest[1]) or carry.manifest()
    if not os.isfile(manifest) then
        raise("cannot read the manifest %s", manifest)
    end
    if given.paths then
        for _, found in ipairs(carry.paths(manifest)) do
            print(found)
        end
        return
    end
    local intact = carry.check(tree.engine_source(given.tree), manifest, {print = true})
    if not intact then
        raise("CARRY BROKEN - the tree no longer holds what this port depends on")
    end
    print("carry intact")
end
