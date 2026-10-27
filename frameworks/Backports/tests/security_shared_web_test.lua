local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local tests = path.join(backports, "tests", "Security", "shared_web")
local source = path.join(backports, "src", "Security", "SharedWebCredentials8.m")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-Wno-deprecated-declarations", "-fblocks"}, args))
end

local function run(program, args)
    os.execv(program, args or {}, {stdout = program .. ".out"})
    return io.readfile(program .. ".out")
end

function main()
    local out = workspace.run("backports-tests", "SecuritySharedWeb")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local fixture = path.join(tests, "main.c")
    clang({"-o", host, fixture, "-framework", "CoreFoundation", "-framework", "Security"})
    clang({"-fobjc-arc", "-o", backport, fixture, source, "-framework", "Foundation", "-framework", "CoreFoundation",
        "-framework", "Security"})
    local expected, got = run(host), run(backport)
    assert(#expected > 0, "the host shared web credential program printed nothing")
    assert(expected == got, "the backport shared web credentials differ from the host in " .. out)

    local contract = path.join(out, "contract")
    clang({"-fobjc-arc", "-o", contract, path.join(tests, "contract.c"), source, "-framework", "Foundation",
        "-framework", "CoreFoundation", "-framework", "Security"})
    assert(run(contract, {"unentitled"}) == "request unentitled: credentials=NULL error=NSOSStatusErrorDomain/-34018\n",
        "a process without the associated domain entitlement got another answer in " .. out)
end
