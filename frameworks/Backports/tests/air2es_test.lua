local limits = import("air2es_limits", {rootdir = path.join(os.scriptdir(), "..", "tools")})

local function shader(header, body)
    return "#version 100\nvoid main() {\n    for (" .. header .. ") {\n" .. body .. "    }\n}\n"
end

local CASES = {
    {name = "a constant loop", source = shader("int t0 = 0; t0 < 61; t0++", "        t1 = t0;\n")},
    {name = "a parenthesized negative start with +=", source = shader("int t0 = (-3); t0 <= 2; t0 += 1", "        t1 = t0;\n")},
    {name = "a counting-down loop", source = shader("int t0 = 61; t0 > 0; t0--", "        t1 = t0;\n")},
    {name = "a float index with a constant step", source = shader("float f = 0.0; f < 1.0; f += 0.25", "        t1 = f;\n")},
    {name = "a comparison of the index in the body", source = shader("int t0 = 0; t0 < 4; t0++", "        if (t0 == 3) { t1 = 1.0; }\n")},
    {name = "a non-constant bound", expect = "a for loop whose bound is not a constant-expression",
     source = shader("int t0 = 0; t0 < n; t0++", "        t1 = t0;\n")},
    {name = "a non-constant start", expect = "starts at something other than a constant-expression",
     source = shader("int t0 = n; t0 < 4; t0++", "        t1 = t0;\n")},
    {name = "an update that is not ++, -- or += a constant", expect = "update is not ++, --, += or -= a constant",
     source = shader("int t0 = 1; t0 < 64; t0 *= 2", "        t1 = t0;\n")},
    {name = "a body that assigns the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0 = 3;\n")},
    {name = "a body that adds to the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0 += 1;\n")},
    {name = "a body that increments the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0++;\n")},
    {name = "a nested loop that declares the index again", expect = "declares its index t0 again",
     source = shader("int t0 = 0; t0 < 4; t0++", "        for (int t0 = 0; t0 < 2; t0++) {\n            t1 = 1.0;\n        }\n")},
    {name = "a while loop", expect = "a while or do-while loop",
     source = "#version 100\nvoid main() {\n    while (t1 < 4.0) {\n        t1 += 1.0;\n    }\n}\n"},
    {name = "an array index that is not constant", expect = "an array index that is not a constant-index-expression",
     source = "#version 100\nvoid main() {\n    t1 = a[i];\n}\n"},
    {name = "a constant array index", source = "#version 100\nvoid main() {\n    t1 = a[2];\n}\n"},
}

local toolDirectory = path.join(os.scriptdir(), "..", "tools")
local sampling = import("metal_sampler_table", {rootdir = toolDirectory})
local toolchain = import("metal_toolchain", {rootdir = toolDirectory})
local sourceDirectory = path.join(os.scriptdir(), "..", "src", "air2es")

local function failure(fn, argument)
    local message
    try {
        function () fn(argument) end,
        catch {
            function (errors)
                message = errors or "failed"
            end
        }
    }
    return message
end

local DECODE_DRIVER = [[
#include <cstdio>
#include <vector>

#include "samplers.h"

using namespace air2es;

int main()
{
    std::vector<SamplerRow> rows = {
        {0x10, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 1},
        {0x20, "repeat", "clamp_to_edge", "clamp_to_edge", "linear", "linear", "none", "normalized", "never", 0.0f, 1000.0f, 1},
        {0x30, "mirrored_repeat", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 1},
        {0x40, "clamp_to_zero", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 1},
        {0x50, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "linear", "linear", "linear", "normalized", "never", 0.0f, 1000.0f, 1},
        {0x60, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "pixel", "never", 0.0f, 1000.0f, 1},
        {0x70, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 2},
        {0x80, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 1.0f, 1000.0f, 1},
        {0x90, "clamp_to_edge", "clamp_to_edge", "repeat", "nearest", "nearest", "none", "normalized", "less", 0.0f, 1000.0f, 1},
        {0xa0, "clamp_to_zero", "clamp_to_zero", "clamp_to_zero", "linear", "linear", "none", "normalized", "never", 0.0f, 1000.0f, 1},
        {0xb0, "clamp_to_zero", "clamp_to_edge", "clamp_to_edge", "linear", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 1},
    };
    const char *names[] = {"clamp", "repeat", "mirrored", "zero", "mip", "pixel", "aniso", "lod", "compare", "zeroLinear", "zeroMixed"};
    for (size_t i = 0; i < rows.size(); i++) {
        GLESSampler sampler;
        std::string refusal;
        if (decodeSampler(rows[i].state, rows, sampler, refusal))
            printf("%s ok %s %s %s %s\n", names[i], sampler.wrapS.c_str(), sampler.wrapT.c_str(),
                   sampler.minFilter.c_str(), sampler.magFilter.c_str());
        else
            printf("%s refused %s\n", names[i], refusal.c_str());
    }
    GLESSampler sampler;
    std::string refusal;
    if (!decodeSampler(0x99, rows, sampler, refusal))
        printf("unknown refused %s\n", refusal.c_str());
    return 0;
}
]]

local DECODE_EXPECTED = {
    "clamp ok clamp_to_edge clamp_to_edge nearest nearest",
    "repeat ok repeat clamp_to_edge linear linear",
    "mirrored refused a mirrored repeat address, which OpenGL ES 2 does not have",
    "zero ok clamp_to_zero clamp_to_edge nearest nearest",
    "mip refused a linear mipmap filter, and the textures of a translated shader have no mipmaps",
    "pixel refused pixel coordinates, which the translated shader does not scale to texture coordinates",
    "aniso refused anisotropic filtering, which OpenGL ES 2 does not have",
    "lod refused a level-of-detail clamp that starts above zero, which OpenGL ES 2 does not clamp",
    "compare ok clamp_to_edge clamp_to_edge nearest nearest",
    "zeroLinear ok clamp_to_zero clamp_to_zero linear linear",
    "zeroMixed refused a clamp-to-zero address with a minification filter and a magnification filter that differ: the level of detail that selects between them is not computed",
    "unknown refused a constexpr sampler with the state 0x0000000000000099 that the sampler table does not carry: derive it with tools/metal_sampler_table.lua",
}

function samplerChecks()
    local rows = {}
    for line in io.readfile(path.join(sourceDirectory, "samplers.inc")):gmatch("[^\n]+") do
        table.insert(rows, line)
    end
    assert(#rows == #sampling.descriptors(), "samplers.inc has " .. #rows .. " rows, the generator makes " .. #sampling.descriptors())
    assert(sampling.rowLine("0x807bff0000080a49", sampling.baseline()) ==
           '    {0x807bff0000080a49ULL, "clamp_to_edge", "clamp_to_edge", "clamp_to_edge", "nearest", "nearest", "none", "normalized", "never", 0.0f, 1000.0f, 1u},',
           "the row format changed")
    assert(sampling.declaration(sampling.baseline()) ==
           "s_address::clamp_to_edge, t_address::clamp_to_edge, r_address::clamp_to_edge, min_filter::nearest, mag_filter::nearest, mip_filter::none, coord::normalized, compare_func::never",
           "the declaration of the baseline sampler changed")
    local found = sampling.parseSamplers("air k_3 0x807bff0000080a49\nair k_4 0x807bff0000084a92\n")
    assert(found[3] == "0x807bff0000080a49" and found[4] == "0x807bff0000084a92", "parseSamplers reads the wrong states")
    assert(failure(sampling.parseSamplers, "air k_3 nothing\n"), "parseSamplers accepted a line it cannot read")
    assert(not sampling.allowed({s = "clamp_to_edge", t = "clamp_to_edge", r = "clamp_to_edge", min = "nearest", mag = "linear", mip = "none", coord = "pixel", compare = "never"}),
           "a pixel-coordinate sampler with unequal filters is not refused")
    assert(sampling.allowed(sampling.baseline()), "the baseline sampler is refused")

    assert(failure(toolchain.verify, nil), "an unset dmg was accepted")
    local bogus = path.join(os.tmpdir(), "air2es-sampler-test-bogus.dmg")
    io.writefile(bogus, "not a disk image")
    local message = failure(toolchain.verify, bogus)
    os.rm(bogus)
    assert(message and message:find("is not the pinned image", 1, true), "a dmg with another sha256 was accepted: " .. tostring(message))

    local directory = path.join(os.tmpdir(), "air2es-sampler-test")
    os.mkdir(directory)
    io.writefile(path.join(directory, "driver.cpp"), DECODE_DRIVER)
    local binary = path.join(directory, "driver")
    os.vrunv("c++", {"-std=c++20", "-I", sourceDirectory, path.join(directory, "driver.cpp"),
                     path.join(sourceDirectory, "samplers.cpp"), "-o", binary})
    local output = os.iorunv(binary)
    local got = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(got, line)
    end
    assert(#got == #DECODE_EXPECTED, "the decode driver printed " .. #got .. " lines")
    for index, expected in ipairs(DECODE_EXPECTED) do
        assert(got[index] == expected, "decode line " .. index .. " is '" .. got[index] .. "', expected '" .. expected .. "'")
    end
    os.rm(directory)
end

local CAPPED = path.join(os.scriptdir(), "air2es", "capped_buffer")

function cappedBufferChecks()
    local binary = path.join(os.scriptdir(), "..", "..", "..", "build", "macosx", "arm64", "release", "air2es")
    assert(os.isfile(binary), "air2es is not built: configure with --air2es=y, then ./xmakew build air2es")
    local work = path.join(os.tmpdir(), "air2es-capped-buffer-test")
    if os.isdir(work) then
        os.rm(work)
    end
    os.mkdir(work)
    local folder = path.join(work, "capped.es2")
    local output = os.iorunv(binary, {CAPPED .. ".metallib", folder})
    assert(output:find("OK callBlobVertex vertex", 1, true), "callBlobVertex is not translated: " .. output)
    assert(output:find("REFUSED uncappedVertex: an address this emitter does not read", 1, true),
           "uncappedVertex, which has no host cap, is not refused by name: " .. output)
    for _, name in ipairs({"callBlobVertex.vertex.glsl", "callBlobVertex.vertex.json", "library.json"}) do
        local expected = io.readfile(path.join(CAPPED .. ".golden", name))
        local got = io.readfile(path.join(folder, name))
        assert(got == expected, name .. " differs from its golden output")
    end
    local glsl = io.readfile(path.join(folder, "callBlobVertex.vertex.glsl"))
    local uniforms = 0
    for _ in glsl:gmatch("uniform float positions_%d;") do
        uniforms = uniforms + 1
    end
    assert(uniforms == 8, "expected 8 element uniforms for the capped buffer, got " .. uniforms)
    assert(glsl:find("(t0 == 0) ? positions_0 : ", 1, true), "the dynamic index is not a select chain over the elements")
    os.rm(work)
end

local SAMPLING = path.join(os.scriptdir(), "air2es", "sample_mac")

function samplingChecks()
    local binary = path.join(os.scriptdir(), "..", "..", "..", "build", "macosx", "arm64", "release", "air2es")
    assert(os.isfile(binary), "air2es is not built: configure with --air2es=y, then ./xmakew build air2es")
    local work = path.join(os.tmpdir(), "air2es-sampling-test")
    if os.isdir(work) then
        os.rm(work)
    end
    os.mkdir(work)
    local folder = path.join(work, "sample_mac.es2")
    local output = os.iorunv(binary, {SAMPLING .. ".metallib", folder})
    assert(output:find("OK sampleVertex vertex", 1, true), "sampleVertex is not translated: " .. output)
    assert(output:find("OK sampleFragment fragment", 1, true), "sampleFragment, a nearest sample of a macOS texture, is not translated: " .. output)
    assert(output:find("REFUSED sampleMinLodFragment: a sample with a minimum level of detail clamp this emitter does not map", 1, true),
           "sampleMinLodFragment, a sample with min_lod_clamp(1.0), is not refused by name: " .. output)
    for _, name in ipairs({"sampleFragment.fragment.glsl", "sampleFragment.fragment.json", "library.json"}) do
        local expected = io.readfile(path.join(SAMPLING .. ".golden", name))
        local got = io.readfile(path.join(folder, name))
        assert(got == expected, name .. " differs from its golden output")
    end
    os.rm(work)
end

local EXIT = path.join(os.scriptdir(), "air2es", "exit_mac")

function exitChecks()
    local binary = path.join(os.scriptdir(), "..", "..", "..", "build", "macosx", "arm64", "release", "air2es")
    assert(os.isfile(binary), "air2es is not built: configure with --air2es=y, then ./xmakew build air2es")
    local work = path.join(os.tmpdir(), "air2es-exit-test")
    if os.isdir(work) then
        os.rm(work)
    end
    os.mkdir(work)
    local folder = path.join(work, "exit_mac.es2")
    local output = os.iorunv(binary, {EXIT .. ".metallib", folder})
    assert(output:find("OK exitVertex vertex", 1, true), "exitVertex is not translated: " .. output)
    assert(output:find("OK exitFragment fragment", 1, true), "exitFragment, a constant loop with a break and two exits, is not translated: " .. output)
    for _, name in ipairs({"exitFragment.fragment.glsl", "exitFragment.fragment.json", "library.json"}) do
        local expected = io.readfile(path.join(EXIT .. ".golden", name))
        local got = io.readfile(path.join(folder, name))
        assert(got == expected, name .. " differs from its golden output")
    end
    os.rm(work)
end

local DERIV = path.join(os.scriptdir(), "air2es", "deriv_mac")

function derivChecks()
    local binary = path.join(os.scriptdir(), "..", "..", "..", "build", "macosx", "arm64", "release", "air2es")
    assert(os.isfile(binary), "air2es is not built: configure with --air2es=y, then ./xmakew build air2es")
    local work = path.join(os.tmpdir(), "air2es-deriv-test")
    if os.isdir(work) then
        os.rm(work)
    end
    os.mkdir(work)
    local folder = path.join(work, "deriv_mac.es2")
    local output = os.iorunv(binary, {DERIV .. ".metallib", folder})
    assert(output:find("OK derivFragment fragment", 1, true), "derivFragment, a dfdx of a float2 and a fwidth of a float3, is not translated: " .. output)
    for _, name in ipairs({"derivFragment.fragment.glsl", "derivFragment.fragment.json", "library.json"}) do
        local expected = io.readfile(path.join(DERIV .. ".golden", name))
        local got = io.readfile(path.join(folder, name))
        assert(got == expected, name .. " differs from its golden output")
    end
    os.rm(work)
end

local LOOP = path.join(os.scriptdir(), "air2es", "loop_mac")

function loopChecks()
    local binary = path.join(os.scriptdir(), "..", "..", "..", "build", "macosx", "arm64", "release", "air2es")
    assert(os.isfile(binary), "air2es is not built: configure with --air2es=y, then ./xmakew build air2es")
    local work = path.join(os.tmpdir(), "air2es-loop-test")
    if os.isdir(work) then
        os.rm(work)
    end
    os.mkdir(work)
    local folder = path.join(work, "loop_mac.es2")
    local output = os.iorunv(binary, {LOOP .. ".metallib", folder})
    assert(output:find("OK loopFragment fragment", 1, true), "loopFragment, a loop whose bound is a uniform and whose body reads a capped vector buffer, is not translated: " .. output)
    for _, name in ipairs({"loopFragment.fragment.glsl", "loopFragment.fragment.json", "library.json"}) do
        local expected = io.readfile(path.join(LOOP .. ".golden", name))
        local got = io.readfile(path.join(folder, name))
        assert(got == expected, name .. " differs from its golden output")
    end
    os.rm(work)
end

function main()
    for _, case in ipairs(CASES) do
        local reason = limits.check(case.source)
        if case.expect then
            assert(reason and reason:find(case.expect, 1, true),
                   case.name .. ": expected a refusal containing '" .. case.expect .. "', got " .. tostring(reason))
        else
            assert(reason == nil, case.name .. ": expected to pass, refused with " .. tostring(reason))
        end
    end
    print("air2es limits: all %d cases passed", #CASES)
    samplerChecks()
    print("air2es samplers: the table, the generator's pieces, the pin and the decode passed")
    cappedBufferChecks()
    print("air2es capped buffers: the host cap gives eight element uniforms and a select chain, and no cap is refused")
    samplingChecks()
    print("air2es sampling: the nine-operand macOS sample translates with a zero minimum LOD clamp, and a nonzero one is refused by name")
    exitChecks()
    print("air2es exit: a constant loop with a break and two exits translates, and matches its golden output")
    derivChecks()
    print("air2es derivatives: dfdx of a float2 and fwidth of a float3 translate, and match their golden output")
    loopChecks()
    print("air2es loops: a loop bounded by a uniform, with a capped float4 buffer read in its body, translates and matches its golden output")
end
