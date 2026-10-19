import("lib.detect.find_tool")
import("byteorder")

local function octal(value, width)
    return string.format("%0" .. (width - 1) .. "o", value) .. "\0"
end

local function header(name, mode, size, typeflag, linkname)
    local prefix = ""
    if #name > 100 then
        local cut = name:sub(1, 155):match(".*()/")
        if not cut or #name - cut > 100 then
            raise("%s is too long a path for a tar header", name)
        end
        prefix, name = name:sub(1, cut - 1), name:sub(cut + 1)
    end
    local fields = {
        name .. string.rep("\0", 100 - #name),
        octal(mode, 8), octal(0, 8), octal(0, 8), octal(size, 12), octal(0, 12),
        "        ",
        typeflag,
        (linkname or "") .. string.rep("\0", 100 - #(linkname or "")),
        "ustar\0", "00",
        "root" .. string.rep("\0", 28), "root" .. string.rep("\0", 28),
        octal(0, 8), octal(0, 8),
        prefix .. string.rep("\0", 155 - #prefix),
        string.rep("\0", 12)
    }
    local block = table.concat(fields)
    local sum = 0
    for index = 1, #block do
        sum = sum + block:byte(index)
    end
    return block:sub(1, 148) .. string.format("%06o", sum) .. "\0 " .. block:sub(157)
end

local function padded(content)
    local remainder = #content % 512
    return remainder == 0 and content or content .. string.rep("\0", 512 - remainder)
end

function tar(members)
    local parts = {}
    for _, member in ipairs(members) do
        if member.directory then
            table.insert(parts, header(member.name, 493, 0, "5"))
        elseif member.link then
            table.insert(parts, header(member.name, 511, 0, "2", member.link))
        else
            table.insert(parts, header(member.name, member.mode, #member.data, "0"))
            table.insert(parts, padded(member.data))
        end
    end
    table.insert(parts, string.rep("\0", 1024))
    return table.concat(parts)
end

function gzip(content)
    local tool = assert(find_tool("gzip"), "gzip is part of macOS; a .deb cannot be written without it")
    local input = os.tmpfile()
    io.writefile(input, content, {encoding = "binary"})
    os.vrunv(tool.program, {"-n", "-9", "-f", input})
    local compressed = io.readfile(input .. ".gz", {encoding = "binary"})
    os.rm(input .. ".gz")
    return compressed
end

function tree_members(root)
    local members = {{name = "./", directory = true}}
    local entries = {}
    for _, entry in ipairs(os.filedirs(path.join(root, "**"))) do
        table.insert(entries, path.relative(entry, root))
    end
    byteorder.sort(entries)
    for _, relative in ipairs(entries) do
        local full = path.join(root, relative)
        if os.islink(full) then
            table.insert(members, {name = "./" .. relative, link = os.readlink(full)})
        elseif os.isdir(full) then
            table.insert(members, {name = "./" .. relative .. "/", directory = true})
        else
            local executable = os.isexec(full)
            table.insert(members, {name = "./" .. relative, mode = executable and 493 or 420,
                                   data = io.readfile(full, {encoding = "binary"})})
        end
    end
    return members
end

function installed_size(root)
    local size = 0
    for _, file in ipairs(os.files(path.join(root, "**"))) do
        size = size + os.filesize(file)
    end
    return (size + 1023) // 1024
end

function control_fields(control)
    local text = io.readfile(control):gsub("\n+$", "")
    local fields = {}
    for key, value in text:gmatch("([%a%-]+):[ \t]*([^\n]*)") do
        fields[key] = value
    end
    return fields, text
end

function control_text(control, version, root, depends)
    local fields, text = control_fields(control)
    if depends and #depends > 0 then
        local added = table.concat(depends, ", ")
        local lines, found = {}, false
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            if line:startswith("Depends:") then
                line = line .. ", " .. added
                found = true
            end
            table.insert(lines, line)
        end
        if not found then
            table.insert(lines, "Depends: " .. added)
        end
        text = table.concat(lines, "\n")
        fields.Depends = fields.Depends and (fields.Depends .. ", " .. added) or added
    end
    if text:find("\nVersion:") or text:startswith("Version:") or text:find("Installed%-Size:") then
        raise("%s must not carry Version or Installed-Size; the build writes them", control)
    end
    for _, required in ipairs({"Package", "Architecture"}) do
        if not fields[required] then
            raise("%s has no %s field", control, required)
        end
    end
    return fields, text .. "\nVersion: " .. version .. "\nInstalled-Size: " .. installed_size(root) .. "\n"
end

function write(opt)
    local fields, control = control_text(opt.control, opt.version, opt.root, opt.depends)
    local control_members = {{name = "./", directory = true}, {name = "./control", mode = 420, data = control}}
    if opt.scripts and os.isdir(opt.scripts) then
        local names = os.files(path.join(opt.scripts, "*"))
        byteorder.sort(names)
        for _, script in ipairs(names) do
            table.insert(control_members, {name = "./" .. path.filename(script), mode = 493,
                                           data = io.readfile(script, {encoding = "binary"})})
        end
    end
    local parts = {
        {"debian-binary", "2.0\n"},
        {"control.tar.gz", gzip(tar(control_members))},
        {"data.tar.gz", gzip(tar(tree_members(opt.root)))}
    }
    local output = path.join(opt.outputdir, string.format("%s_%s_%s.deb", fields.Package, opt.version, fields.Architecture))
    local archive = {"!<arch>\n"}
    for _, part in ipairs(parts) do
        local name, data = part[1], part[2]
        table.insert(archive, string.format("%-16s%-12d%-6d%-6d%-8o%-10d`\n", name, 0, 0, 0, 33188, #data))
        table.insert(archive, data)
        if #data % 2 == 1 then
            table.insert(archive, "\n")
        end
    end
    os.mkdir(opt.outputdir)
    io.writefile(output, table.concat(archive), {encoding = "binary"})
    return output
end
