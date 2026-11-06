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
    };
    const char *names[] = {"clamp", "repeat", "mirrored", "zero", "mip", "pixel", "aniso", "lod", "compare"};
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
    "zero refused a clamp-to-zero address, which OpenGL ES 2 does not have",
    "mip refused a linear mipmap filter, and the textures of a translated shader have no mipmaps",
    "pixel refused pixel coordinates, which the translated shader does not scale to texture coordinates",
    "aniso refused anisotropic filtering, which OpenGL ES 2 does not have",
    "lod refused a level-of-detail clamp that starts above zero, which OpenGL ES 2 does not clamp",
    "compare ok clamp_to_edge clamp_to_edge nearest nearest",
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
end
