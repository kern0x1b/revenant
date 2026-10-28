local url = "https://github.com/kmackay/micro-ecc.git"
local commit = "541b3a78026420a3e369c4c9281c396b5e531113"

function fetch(out)
    local source = path.join(out, "micro-ecc")
    if not os.isfile(path.join(source, "uECC.c")) then
        os.vrunv("git", {"clone", "--quiet", url, source})
        os.vrunv("git", {"-C", source, "checkout", "--quiet", commit})
    end
    return source
end
