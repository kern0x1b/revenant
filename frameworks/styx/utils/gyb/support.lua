-- support.lua: what the generators in this directory share. Each one is the port of a .gyb template: its literal text is
-- the template's, byte for byte, with every ${name} filled from the environment the template's loops set, and the
-- output is the GENERATED-*.swift file the Swift package compiles.
--
--     xmake l utils/gyb/RootProtocols.lua        (utils/recursively_gyb.sh runs every generator)

-- the template header every generated file starts with: utils/template_header.txt without its trailing newlines,
-- which is what the shell's $(< file) gave the template
function header()
    local text = io.readfile(path.join(os.scriptdir(), "..", "template_header.txt"))
    return (string.gsub(text, "\n+$", ""))
end

-- the literal block with each ${name} replaced by env[name]; a name that env does not hold is an error
function fill(text, env)
    return (string.gsub(text, "%${([%w_]+)}", function(name)
        if env[name] == nil then
            io.stderr:write("gyb: no value for ${" .. name .. "}\n")
            os.exit(1)
        end
        return env[name]
    end))
end

-- the Swift sources a generator writes: the file is replaced whole
function write(file, text)
    io.writefile(file, text)
end
