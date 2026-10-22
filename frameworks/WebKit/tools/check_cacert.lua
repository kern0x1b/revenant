import("net.http")

local EXPECTED = "f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9"
local UPSTREAM = "https://curl.se/ca/cacert.pem"

local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/check_cacert.lua [--upstream]
  verifies that examples/webview-host/cacert.pem, the trust store the standalone application carries, is the reviewed
  bundle; --upstream also compares it with what curl.se serves today.]]

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given = tree.arguments({...}, {upstream = "switch", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local bundle = tree.member("examples", "webview-host", "cacert.pem")
    if not os.isfile(bundle) then
        raise("check_cacert: cannot read %s", bundle)
    end
    local actual = hash.sha256(bundle)
    if actual ~= EXPECTED then
        raise("examples/webview-host/cacert.pem is not the reviewed bundle\n  expected %s\n  found    %s", EXPECTED, actual)
    end
    print("examples/webview-host/cacert.pem matches the reviewed bundle (" .. EXPECTED .. ")")
    if not given.upstream then
        return
    end
    local downloaded = os.tmpfile() .. ".pem"
    http.download(UPSTREAM, downloaded)
    local remote = hash.sha256(downloaded)
    os.tryrm(downloaded)
    if remote == actual then
        print("and it is byte-for-byte what " .. UPSTREAM .. " serves today")
    else
        print(UPSTREAM .. " now serves a different extract (" .. remote .. ").")
        print("A trust store changes only after somebody reads the change:")
        print("  1. diff the two files and see which authorities moved")
        print("  2. replace examples/webview-host/cacert.pem")
        print("  3. put the new hash in EXPECTED in tools/check_cacert.lua, in the same commit")
    end
end
