local template = import("template", {rootdir = os.scriptdir(), anonymous = true})

local function usage(message)
    raise("gyb: " .. message .. "\nusage: xmake l gyb/main.lua [-D NAME=VALUE]... [--line-directive TEXT] [--path DIR]... [-o FILE] FILE")
end

local function add_define(defines, text)
    local name, value = text:match("^([^=]*)=(.*)$")
    if not name then
        usage("bad define '" .. text .. "'")
    end
    defines[name] = value
end

function main(...)
    local args = {...}
    local defines, paths = {}, {}
    local output, input, directive
    local i = 1
    local function value(option)
        i = i + 1
        if args[i] == nil then
            usage(option .. " needs a value")
        end
        return args[i]
    end
    while i <= #args do
        local a = args[i]
        if a == "-D" then
            add_define(defines, value(a))
        elseif a:sub(1, 2) == "-D" then
            add_define(defines, a:sub(3))
        elseif a == "-o" then
            output = value(a)
        elseif a:sub(1, 2) == "-o" then
            output = a:sub(3)
        elseif a == "--line-directive" then
            directive = value(a)
        elseif a:sub(1, 17) == "--line-directive=" then
            directive = a:sub(18)
        elseif a == "--path" then
            paths[#paths + 1] = path.absolute(value(a))
        elseif a:sub(1, 7) == "--path=" then
            paths[#paths + 1] = path.absolute(a:sub(8))
        elseif a:sub(1, 1) == "-" and #a > 1 then
            usage("unknown option '" .. a .. "'")
        elseif input then
            usage("only one template file may be given")
        else
            input = a
        end
        i = i + 1
    end
    if not input then
        usage("no template file given")
    end
    local text = template.expand(input, {defines = defines, line_directive = directive, paths = paths})
    if output and output ~= "-" then
        io.writefile(output, text)
    else
        io.write(text)
    end
end
