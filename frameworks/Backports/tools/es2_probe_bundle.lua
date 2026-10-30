ROOT = "/var/revenant/es2"

local STAGES = {vertex = "vertex", fragment = "fragment", kernel = "fragment"}

local function declarations(source)
    local out = {}
    for line in string.gmatch(source, "[^\n]+") do
        local declaration = string.match(line, "^%s*varying%s+(.-)%s*;")
        if declaration then
            table.insert(out, declaration)
        end
    end
    return out
end

local function typeOf(declaration)
    return string.match(declaration, "(%S+)%s+%S+$")
end

local function nameOf(declaration)
    return string.match(declaration, "(%S+)$")
end

local function companionVertex(declarations)
    local lines = {"precision mediump float;"}
    local body = {"gl_Position = vec4(0.0);"}
    for _, declaration in ipairs(declarations) do
        table.insert(lines, "varying " .. declaration .. ";")
        table.insert(body, nameOf(declaration) .. " = " .. typeOf(declaration) .. "(0.0);")
    end
    return table.concat(lines, "\n") .. "\nvoid main() {\n    " .. table.concat(body, "\n    ") .. "\n}\n"
end

local function companionFragment(declarations)
    local lines = {"precision mediump float;"}
    for _, declaration in ipairs(declarations) do
        table.insert(lines, "varying " .. declaration .. ";")
    end
    return table.concat(lines, "\n") .. "\nvoid main() {\n    gl_FragColor = vec4(0.0);\n}\n"
end

function main(out, ...)
    local folders = {...}
    assert(out and #folders > 0, "usage: es2_probe_bundle.lua OUT FOLDER.es2...")
    os.mkdir(out)
    local manifest = {"# name\tstage\ttranslated\tcompanion"}
    local programs = 0
    for _, folder in ipairs(folders) do
        local prefix = string.gsub(path.basename(folder), "%.es2$", "")
        for _, file in ipairs(os.files(path.join(folder, "*.glsl"))) do
            local name, stage = string.match(path.basename(file), "^(.+)%.(%a+)%.glsl$")
            local kind = STAGES[stage]
            if name and kind then
                local source = io.readfile(file)
                local bundled = prefix .. "." .. name .. "." .. stage .. ".glsl"
                local companion = prefix .. "." .. name .. ".companion." .. kind .. ".glsl"
                local other = kind == "vertex" and companionFragment(declarations(source)) or companionVertex(declarations(source))
                io.writefile(path.join(out, bundled), source)
                io.writefile(path.join(out, companion), other)
                table.insert(manifest, string.format("%s.%s\t%s\t%s/%s\t%s/%s", prefix, name, kind, ROOT, bundled, ROOT, companion))
                programs = programs + 1
            end
        end
    end
    io.writefile(path.join(out, "manifest.txt"), table.concat(manifest, "\n") .. "\n")
    print(string.format("bundle ok: %d programs in %s", programs, out))
end
