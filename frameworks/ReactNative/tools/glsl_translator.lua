local function run(program, args, log)
    local failed = nil
    try {
        function ()
            os.runv(program, args, {stdout = log, stderr = log})
        end,
        catch {
            function (errors)
                failed = tostring(errors or "failed")
            end
        }
    }
    return failed
end

local MAX_SOURCE_BYTES = 1024 * 1024

local function translate(corpus, spirvcross, glslang, outdir)
    os.mkdir(outdir)
    local names = {"meshbasic", "meshstandard", "instanced-shadermaterial"}
    local stages = {vert = "vert", frag = "frag"}
    for _, name in ipairs(names) do
        for stage in pairs(stages) do
            local base = path.join(outdir, name .. "." .. stage)
            local source = io.readfile(path.join(corpus, name .. "." .. stage))
            if #source > MAX_SOURCE_BYTES then
                print(string.format("%s.%s: REJECTED, %d bytes is over the %d-byte source limit", name, stage, #source, MAX_SOURCE_BYTES))
                goto continue
            end
            local renamed = (source:gsub("average%(", "revenant_average("))
            io.writefile(base .. ".renamed", renamed)
            local v310 = (renamed:gsub("^#version 300 es\n", "#version 310 es\n"))
            io.writefile(base .. ".310", v310)
            local spv = base .. ".spv"
            local es100 = base .. ".es100"

            local es300 = run(glslang, {"-S", stage, base .. ".renamed"}, base .. ".es300.log")
            local frontend = run(glslang, {"-G", "--aml", "-S", stage, base .. ".310", "-o", spv}, base .. ".glslang.log")
            local cross = nil
            local es100check = nil
            if not frontend then
                cross = run(spirvcross, {"--es", "--version", "100", "--output", es100, spv}, base .. ".cross.log")
            end
            if not cross and not frontend then
                es100check = run(glslang, {"-S", stage, es100}, base .. ".es100.log")
            end
            print(string.format("%s.%s: es300 %s; spirv %s; es100 %s",
                name, stage,
                es300 and ("FAILED " .. es300) or "ok",
                frontend and ("FAILED " .. frontend) or "ok",
                frontend and "not run" or (cross and ("FAILED " .. cross)) or (es100check and ("FAILED " .. es100check)) or "ok"))
        end
        ::continue::
    end
end

function main(spirvcross, glslang, outdir, corpus)
    corpus = corpus or path.join(os.scriptdir(), "..", "..", "Backports", "tests", "OpenGLES", "glsl_translator", "corpus")
    translate(corpus, spirvcross, glslang, outdir or path.join(os.tmpdir(), "glsl-translator"))
end
