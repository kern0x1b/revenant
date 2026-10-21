local webauth = path.absolute(path.join(os.scriptdir(), "..", "src", "CloudKit", "webauth"))

function main()
    local header = io.readfile(path.join(webauth, "RevenantCKWebAuth.h"))
    local wrapper = io.readfile(path.join(webauth, "RevenantCKWebAuth.c"))
    local declared = 0
    for name in header:gmatch("%s(Revenant%w+)%s*%(") do
        declared = declared + 1
        local defined = wrapper:match("[%a][%w%* ]*" .. name .. "%s*%(")
        assert(defined, "the header declares " .. name .. " and the source does not define it")
    end
    assert(declared > 0, "the header declares no Revenant function")
    assert(header:find("RevenantCKSHA256"), "the header declares the SHA-256 the message-level pair is built on")
end
