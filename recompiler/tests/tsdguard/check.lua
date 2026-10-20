function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local _
    _, out = corpus.setup("tsdguard", out)
    local binary = path.join(out, "tsdguard")
    os.execv("cc", {"-O0", "-Wall", "-o", binary, path.join(os.scriptdir(), "main.c")})
    os.execv(binary, {}, {timeout = 60000})
end
