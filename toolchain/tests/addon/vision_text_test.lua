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

local function contents(folder, deb)
    return unpacked(folder, members(deb)["data.tar.gz"], "-tzf")
end

local function control_of(folder, deb)
    return unpacked(folder, members(deb)["control.tar.gz"], "-xzOf")
end

function failures(opt)
    local vision_text = import("apple.vision_text", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local root = path.join(folder, "tessdata")
    local share = path.join(root, "share", "tessdata")
    for _, level in ipairs({"fast", "best"}) do
        os.mkdir(path.join(share, level))
    end
    os.mkdir(path.join(root, "licenses"))
    io.writefile(path.join(root, "licenses", "LICENSE"), "license")
    for _, code in ipairs({"eng", "rus", "ukr"}) do
        io.writefile(path.join(share, "fast", code .. ".traineddata"), code)
        io.writefile(path.join(share, "best", code .. ".traineddata"), code)
    end
    io.writefile(path.join(share, "best", "chi_sim.traineddata"), "chi_sim")

    local out = path.join(folder, "out")
    local written = vision_text.write({root = root, workdir = path.join(folder, "work"), outputdir = out})
    local names = {}
    for _, deb in ipairs(written) do
        table.insert(names, path.filename(deb))
    end
    table.sort(names)
    local expected = {"org.revenant.vision-text-best-chi-sim", "org.revenant.vision-text-best-eng", "org.revenant.vision-text-best-rus",
                      "org.revenant.vision-text-best-ukr", "org.revenant.vision-text-fast-eng", "org.revenant.vision-text-fast-rus",
                      "org.revenant.vision-text-fast-ukr"}
    if #written ~= #expected then
        table.insert(found, "one package is written per installed model, got " .. table.concat(names, ", "))
    end
    for _, name in ipairs(expected) do
        local deb = package_named(written, name)
        if not deb then
            table.insert(found, "a package " .. name .. " is written")
        elseif not path.filename(deb):find("_1%.0%+%x+_iphoneos%-arm%.deb$") then
            table.insert(found, "the package " .. name .. " is named after its version and architecture, got " .. path.filename(deb))
        end
    end

    local fast_eng = package_named(written, "org.revenant.vision-text-fast-eng")
    if fast_eng then
        if not contents(folder, fast_eng):find("./usr/share/revenant/tessdata/fast/eng.traineddata", 1, true) or contents(folder, fast_eng):find("/best/", 1, true) then
            table.insert(found, "the fast English package carries the fast English model only: " .. contents(folder, fast_eng))
        end
        if not control_of(folder, fast_eng):find("Package: org.revenant.vision-text-fast-eng\n", 1, true) or not control_of(folder, fast_eng):find("Architecture: iphoneos-arm\n", 1, true) then
            table.insert(found, "the fast English package names itself and its architecture: " .. control_of(folder, fast_eng))
        end
    end
    local chinese = package_named(written, "org.revenant.vision-text-best-chi-sim")
    if chinese and not contents(folder, chinese):find("./usr/share/revenant/tessdata/best/chi_sim.traineddata", 1, true) then
        table.insert(found, "the Chinese package carries its Tesseract model: " .. contents(folder, chinese))
    end
    local russian = package_named(written, "org.revenant.vision-text-best-rus")
    if russian and not contents(folder, russian):find("./usr/share/doc/org.revenant.vision-text-best-rus/LICENSE", 1, true) then
        table.insert(found, "the Russian package carries the tessdata license: " .. contents(folder, russian))
    end

    if table.concat(vision_text.depends(), ",") ~= "org.revenant.vision-text-fast-eng" then
        table.insert(found, "Backports depends on the fast English package, got " .. table.concat(vision_text.depends(), ","))
    end
    if table.concat(vision_text.recommended(), ",") ~= "org.revenant.vision-text-fast-rus,org.revenant.vision-text-fast-ukr" then
        table.insert(found, "Backports recommends the fast Russian and Ukrainian packages, got " .. table.concat(vision_text.recommended(), ","))
    end

    io.writefile(path.join(share, "best", "xyz.traineddata"), "xyz")
    local errors = fixtures.refusal(function () vision_text.write({root = root, workdir = path.join(folder, "work"), outputdir = out}) end)
    if not errors or not errors:find("is not a Vision text model", 1, true) then
        table.insert(found, "a model that names no Vision language is refused: " .. tostring(errors))
    end
    os.rm(path.join(share, "best", "xyz.traineddata"))

    os.rm(path.join(root, "licenses", "LICENSE"))
    errors = fixtures.refusal(function () vision_text.write({root = root, workdir = path.join(folder, "work"), outputdir = out}) end)
    if not errors or not errors:find("is not installed", 1, true) then
        table.insert(found, "a package without the tessdata license is refused: " .. tostring(errors))
    end
    os.tryrm(folder)
    return found
end
