local TOOLS = {
    ld64 = {tool = {"bin", "ld"}, used = "the -fuse-ld= of every armv7 link"},
    llvm = {tool = {"bin", "clang"}, used = "the compiler of every target"}
}

local function explanation(name, version, used)
    return string.format("the %s %s package is required but has no install folder in this configuration, so the apple-ios toolchain has no path for %s "
                         .. "(a nil folder would become the text 'nil/...' in a flag, and the compiler would say 'invalid linker name'). "
                         .. "Either this cache does not hold the build of it that this checkout asks for (its key covers the recipe and its patches, "
                         .. "so a cache made before a change to them holds the older key only), or it was registered without being located (--require=n). "
                         .. "Install it first, by a configure that installs requirements or from its prebuilt (REVENANT_PREBUILT), and configure again",
                         name, version, used)
end

local function resolve(toolchain, required, strict)
    local found, absent = {}, {}
    for _, name in ipairs({"ld64", "llvm"}) do
        local package = required[name]
        local version = toolchain:config(name)
        if package and version then
            local folder = package:installdir()
            if folder then
                found[name] = path.join(folder, TOOLS[name].tool[1], TOOLS[name].tool[2])
            else
                absent[name] = version
                if strict then
                    raise("%s", explanation(name, version, TOOLS[name].used))
                end
            end
        end
    end
    return found, absent
end

function check_tools(toolchain, required)
    return resolve(toolchain, required, false)
end

function load_tools(toolchain, required)
    return resolve(toolchain, required, true)
end
