import("fixtures")

local CONTROL = "Package: org.example.demo\nName: Demo\nArchitecture: iphoneos-arm\nDescription: a demo\n"

local function members(deb)
    local content = io.readfile(deb, {encoding = "binary"})
    assert(content:startswith("!<arch>\n"), deb .. " is not an ar archive")
    local found, order, offset = {}, {}, 8
    while offset < #content do
        local header = content:sub(offset + 1, offset + 60)
        local name = header:sub(1, 16):trim():gsub("/$", "")
        local size = tonumber(header:sub(49, 58):trim())
        found[name] = content:sub(offset + 61, offset + 60 + size)
        table.insert(order, name)
        offset = offset + 60 + size + size % 2
    end
    return found, order
end

local function listing(folder, archive)
    local file = path.join(folder, "listed.tar.gz")
    io.writefile(file, archive, {encoding = "binary"})
    return os.iorunv("tar", {"-tvzf", file, "--numeric-owner"})
end

function failures(opt)
    local debian = import("debian", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local root = path.join(folder, "root")
    local deep = path.join(root, "Library", string.rep("nested/", 16), "file.txt")
    os.mkdir(path.directory(deep))
    io.writefile(deep, "deep")
    os.mkdir(path.join(root, "usr", "bin"))
    io.writefile(path.join(root, "usr", "bin", "tool"), "#!/bin/sh\n")
    os.runv("chmod", {"755", path.join(root, "usr", "bin", "tool")})
    os.ln("tool", path.join(root, "usr", "bin", "alias"))
    local control = path.join(folder, "control")
    io.writefile(control, CONTROL)

    local deb = debian.write({control = control, version = "1.2.3", root = root, outputdir = path.join(folder, "out")})
    if path.filename(deb) ~= "org.example.demo_1.2.3_iphoneos-arm.deb" then
        table.insert(found, "the package is named Package_Version_Architecture.deb, got " .. path.filename(deb))
    end
    local parts, order = members(deb)
    if table.concat(order, ",") ~= "debian-binary,control.tar.gz,data.tar.gz" then
        table.insert(found, "dpkg reads debian-binary, control and data in that order, got " .. table.concat(order, ","))
    end
    if parts["debian-binary"] ~= "2.0\n" then
        table.insert(found, "debian-binary must say 2.0")
    end
    local control_listing = listing(folder, parts["control.tar.gz"])
    if not control_listing:find("%s0%s+0%s")  or not control_listing:find("./control", 1, true) then
        table.insert(found, "control.tar.gz must hold ./control owned by root: " .. control_listing)
    end
    local data_listing = listing(folder, parts["data.tar.gz"])
    for _, expected in ipairs({"./usr/bin/alias -> tool", "-rwxr-xr-x", "file.txt", "./Library/"}) do
        if not data_listing:find(expected, 1, true) then
            table.insert(found, "data.tar.gz must carry " .. expected .. ": " .. data_listing)
        end
    end
    local extracted = path.join(folder, "extracted")
    os.mkdir(extracted)
    io.writefile(path.join(folder, "control.tar.gz"), parts["control.tar.gz"], {encoding = "binary"})
    os.runv("tar", {"-xzf", path.join(folder, "control.tar.gz"), "-C", extracted})
    local written = io.readfile(path.join(extracted, "control"))
    if not written:find("\nVersion: 1.2.3\n", 1, true) or not written:find("\nInstalled%-Size: %d+\n") then
        table.insert(found, "the control file carries the version and installed size: " .. written)
    end

    local first = io.readfile(deb, {encoding = "binary"})
    os.sleep(1100)
    debian.write({control = control, version = "1.2.3", root = root, outputdir = path.join(folder, "out")})
    if io.readfile(deb, {encoding = "binary"}) ~= first then
        table.insert(found, "writing the same tree twice must give the same bytes")
    end

    for _, case in ipairs({{CONTROL, "Depends: org.example.library (>= 2)"},
                           {CONTROL .. "Depends: firmware (>= 6.0)\n", "Depends: firmware (>= 6.0), org.example.library (>= 2)"}}) do
        io.writefile(control, case[1])
        local fields, text = debian.control_text(control, "1.2.3", root, {"org.example.library (>= 2)"})
        local _, count = text:gsub("\nDepends:", "")
        if not text:find("\n" .. case[2]:gsub("%p", "%%%0") .. "\n") or count ~= 1 or fields.Depends ~= case[2]:sub(10) then
            table.insert(found, "a package the build depends on joins the control file's one Depends field as " .. case[2] .. ": " .. text)
        end
    end

    io.writefile(control, CONTROL .. "Version: 9\n")
    local errors = fixtures.refusal(function () debian.write({control = control, version = "1.2.3", root = root, outputdir = folder}) end)
    if not errors or not errors:find("must not carry Version", 1, true) then
        table.insert(found, "a control file carrying its own Version must be refused")
    end
    io.writefile(control, "Name: Demo\n")
    errors = fixtures.refusal(function () debian.write({control = control, version = "1.2.3", root = root, outputdir = folder}) end)
    if not errors or not errors:find("has no Package field", 1, true) then
        table.insert(found, "a control file without Package must be refused")
    end
    os.tryrm(folder)
    return found
end
