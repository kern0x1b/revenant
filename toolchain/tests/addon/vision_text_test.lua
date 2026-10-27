import("fixtures")

local function members(deb)
    local content = io.readfile(deb, {encoding = "binary"})
    local found, offset = {}, 8
    while offset < #content do
        local header = content:sub(offset + 1, offset + 60)
        local name = header:sub(1, 16):trim():gsub("/$", "")
        local size = tonumber(header:sub(49, 58):trim())
        found[name] = content:sub(offset + 61, offset + 60 + size)
        offset = offset + 60 + size + size % 2
    end
    return found
end

local function unpacked(folder, archive, flags)
    local file = path.join(folder, "member.tar.gz")
    io.writefile(file, archive, {encoding = "binary"})
    return os.iorunv("tar", {flags, file})
end

local function package_named(written, name)
    for _, deb in ipairs(written) do
        if path.filename(deb):startswith(name .. "_") then
            return deb
        end
    end
end

function failures(opt)
    local vision_text = import("apple.vision_text", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local root = path.join(folder, "tessdata")
    os.mkdir(path.join(root, "share", "tessdata", "fast"))
    os.mkdir(path.join(root, "share", "tessdata", "best"))
    os.mkdir(path.join(root, "licenses"))
    io.writefile(path.join(root, "licenses", "LICENSE"), "license")
    for _, code in ipairs(vision_text.fast_codes()) do
        io.writefile(path.join(root, "share", "tessdata", "fast", code .. ".traineddata"), code)
    end
    for _, language in ipairs(vision_text.languages()) do
        io.writefile(path.join(root, "share", "tessdata", "best", language.code .. ".traineddata"), language.code)
    end

    local out = path.join(folder, "out")
    local written = vision_text.write({root = root, workdir = path.join(folder, "work"), outputdir = out})
    if #written ~= 1 + #vision_text.languages() then
        table.insert(found, "one fast package and one package per accurate language are written, got " .. #written)
    end
    if not path.filename(written[1]):find("^org%.revenant%.vision%-text%-fast_1%.0%+%x+_iphoneos%-arm%.deb$") then
        table.insert(found, "the fast package is named after its version and architecture, got " .. path.filename(written[1]))
    end

    local fast = members(written[1])
    local fast_data = unpacked(folder, fast["data.tar.gz"], "-tzf")
    for _, code in ipairs(vision_text.fast_codes()) do
        if not fast_data:find("./usr/share/revenant/tessdata/fast/" .. code .. ".traineddata", 1, true) then
            table.insert(found, "the fast package carries " .. code .. ": " .. fast_data)
        end
    end
    local fast_control = unpacked(folder, fast["control.tar.gz"], "-xzOf")
    if not fast_control:find("Package: org.revenant.vision-text-fast\n", 1, true) or not fast_control:find("Architecture: iphoneos-arm\n", 1, true) then
        table.insert(found, "the fast package names itself and its architecture: " .. fast_control)
    end

    local russian = package_named(written, "org.revenant.vision-text-ru")
    local russian_data = unpacked(folder, members(russian)["data.tar.gz"], "-tzf")
    if not russian_data:find("./usr/share/revenant/tessdata/best/rus.traineddata", 1, true) or russian_data:find("/fast/", 1, true) then
        table.insert(found, "the Russian package carries the best Russian model only: " .. russian_data)
    end
    if not russian_data:find("./usr/share/doc/org.revenant.vision-text-ru/LICENSE", 1, true) then
        table.insert(found, "the Russian package carries the tessdata license: " .. russian_data)
    end

    if table.concat(vision_text.recommended(), ",") ~= "org.revenant.vision-text-en,org.revenant.vision-text-ru,org.revenant.vision-text-uk" then
        table.insert(found, "Backports recommends the en, ru and uk packages, got " .. table.concat(vision_text.recommended(), ","))
    end
    if vision_text.fast_package() ~= "org.revenant.vision-text-fast" then
        table.insert(found, "the fast package has the name Backports depends on, got " .. vision_text.fast_package())
    end

    os.rm(path.join(root, "share", "tessdata", "best", "rus.traineddata"))
    local errors = fixtures.refusal(function () vision_text.write({root = root, workdir = path.join(folder, "work"), outputdir = out}) end)
    if not errors or not errors:find("is not installed", 1, true) then
        table.insert(found, "a model the tessdata package does not install is refused: " .. tostring(errors))
    end
    os.tryrm(folder)
    return found
end
