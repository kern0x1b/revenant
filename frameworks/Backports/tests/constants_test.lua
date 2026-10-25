local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

local SECURITY = "/System/Library/Frameworks/Security.framework/Security"
local PHOTOS = "/System/Library/Frameworks/Photos.framework/Photos"

local CASES = {
    {
        symbol = "PHImageManagerMaximumSize",
        kind = "cgsize",
        library = PHOTOS,
        source = "src/Photos/PHImageManager8.m",
        line = "const CGSize PHImageManagerMaximumSize = {-1, -1};",
        mutant = {"{-1, -1}", "{-1, 0}"},
    },
    {
        symbol = "kSecAttrAccessControl",
        kind = "cfstring",
        library = SECURITY,
        source = "src/Security/SecAccessControl8.m",
        line = "const CFStringRef kSecAttrAccessControl = CFSTR(\"accc\");",
        mutant = {"\"accc\"", "\"acc\""},
    },
    {
        symbol = "kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly",
        kind = "cfstring",
        library = SECURITY,
        oracle = "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
        source = "src/Security/SecAccessControl8.m",
        line = "const CFStringRef kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly = CFSTR(\"aku\");",
        mutant = {"\"aku\"", "\"akpu\""},
    },
    {
        symbol = "kSecUseAuthenticationContext",
        kind = "cfstring",
        library = SECURITY,
        source = "src/Security/SecUseAuthentication9.m",
        line = "const CFStringRef kSecUseAuthenticationContext = CFSTR(\"u_AuthCtx\");",
        mutant = {"\"u_AuthCtx\"", "\"u_AuthUI\""},
    },
    {
        symbol = "kSecUseDataProtectionKeychain",
        kind = "cfstring",
        library = SECURITY,
        source = "src/Security/SecurityKeychain13_0.m",
        line = "const CFStringRef kSecUseDataProtectionKeychain = CFSTR(\"nleg\");",
        mutant = {"\"nleg\"", "\"nlg\""},
    },
}

local function print_value(kind, name)
    if kind == "cgsize" then
        return string.format("    CGSize value = %s;\n    printf(\"%%g %%g\\n\", value.width, value.height);\n", name)
    end
    return string.format("    char buffer[256] = \"?\";\n    CFStringGetCString(%s, buffer, sizeof buffer, kCFStringEncodingUTF8);\n    printf(\"%%s\\n\", buffer);\n", name)
end

local function backport_program(case, line)
    return "#include <stdio.h>\n#include <CoreFoundation/CoreFoundation.h>\n#include <CoreGraphics/CoreGraphics.h>\n"
        .. line .. "\nint main(void)\n{\n" .. print_value(case.kind, case.symbol) .. "    return 0;\n}\n"
end

local function oracle_program(case)
    local name = case.oracle or case.symbol
    local read = case.kind == "cgsize" and "CGSize *value = (CGSize *)address;" or "CFStringRef *value = (CFStringRef *)address;"
    local shown = case.kind == "cgsize"
        and "    printf(\"%g %g\\n\", value->width, value->height);\n"
        or "    char buffer[256] = \"?\";\n    CFStringGetCString(*value, buffer, sizeof buffer, kCFStringEncodingUTF8);\n    printf(\"%s\\n\", buffer);\n"
    return "#include <dlfcn.h>\n#include <stdio.h>\n#include <CoreFoundation/CoreFoundation.h>\n#include <CoreGraphics/CoreGraphics.h>\n"
        .. "int main(void)\n{\n    void *library = dlopen(\"" .. case.library .. "\", RTLD_LAZY);\n"
        .. "    if (!library)\n        return 1;\n    void *address = dlsym(library, \"" .. name .. "\");\n"
        .. "    if (!address)\n        return 2;\n    " .. read .. "\n" .. shown .. "    return 0;\n}\n"
end

local function mutated(line, mutant)
    local start, stop = line:find(mutant[1], 1, true)
    assert(start, "the negative control has no " .. mutant[1] .. " in " .. line)
    return line:sub(1, start - 1) .. mutant[2] .. line:sub(stop + 1)
end

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

local function run(exe)
    os.execv(exe, {}, {stdout = exe .. ".out"})
    return io.readfile(exe .. ".out")
end

function main()
    local out = workspace.run("backports-tests", "Constants")
    for _, case in ipairs(CASES) do
        local text = io.readfile(path.join(backports, case.source))
        assert(text:find(case.line, 1, true), "the backport does not define " .. case.symbol .. " as the test expects: " .. case.line)
        local folder = path.join(out, case.symbol)
        os.mkdir(folder)
        local oracle_c = path.join(folder, "oracle.c")
        io.writefile(oracle_c, oracle_program(case))
        local oracle = path.join(folder, "oracle")
        clang({"-framework", "CoreFoundation", "-framework", "CoreGraphics", "-o", oracle, oracle_c})
        local expected = run(oracle)
        assert(#expected > 0, "the host oracle printed nothing for " .. case.symbol)

        local backport_c = path.join(folder, "backport.c")
        io.writefile(backport_c, backport_program(case, case.line))
        local backport = path.join(folder, "backport")
        clang({"-framework", "CoreFoundation", "-framework", "CoreGraphics", "-o", backport, backport_c})
        assert(run(backport) == expected, "the backport value of " .. case.symbol .. " differs from the host in " .. folder)

        local broken_c = path.join(folder, "broken.c")
        io.writefile(broken_c, backport_program(case, mutated(case.line, case.mutant)))
        local broken = path.join(folder, "broken")
        clang({"-framework", "CoreFoundation", "-framework", "CoreGraphics", "-o", broken, broken_c})
        assert(run(broken) ~= expected, "the negative control for " .. case.symbol .. " matched the host in " .. folder)
    end
end
