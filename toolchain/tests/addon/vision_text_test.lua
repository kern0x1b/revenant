import("fixtures")

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
    io.writefile(path.join(share, "fast", "eng.traineddata"), "eng")
    for _, code in ipairs({"eng", "rus", "ukr", "chi_sim"}) do
        io.writefile(path.join(share, "best", code .. ".traineddata"), code)
    end

    local installed = vision_text.installed(root)
    local listed = {}
    for _, model in ipairs(installed.models) do
        table.insert(listed, model.destination)
    end
    table.sort(listed)
    local expected = {"var/lib/revenant/tessdata/best/chi_sim.traineddata", "var/lib/revenant/tessdata/best/eng.traineddata",
                      "var/lib/revenant/tessdata/best/rus.traineddata", "var/lib/revenant/tessdata/best/ukr.traineddata",
                      "var/lib/revenant/tessdata/fast/eng.traineddata"}
    if table.concat(listed, ",") ~= table.concat(expected, ",") then
        table.insert(found, "every installed model is placed under the Vision text folder at its level: " .. table.concat(listed, ","))
    end
    if installed.license ~= path.join(root, "licenses", "LICENSE") then
        table.insert(found, "the tessdata license is the one the package carries: " .. tostring(installed.license))
    end

    io.writefile(path.join(share, "best", "xyz.traineddata"), "xyz")
    local errors = fixtures.refusal(function () vision_text.installed(root) end)
    if not errors or not errors:find("is not a Vision text model", 1, true) then
        table.insert(found, "a model that names no Vision language is refused: " .. tostring(errors))
    end
    os.rm(path.join(share, "best", "xyz.traineddata"))

    os.rm(path.join(root, "licenses", "LICENSE"))
    errors = fixtures.refusal(function () vision_text.installed(root) end)
    if not errors or not errors:find("is not installed", 1, true) then
        table.insert(found, "a tessdata package without its license is refused: " .. tostring(errors))
    end
    os.tryrm(folder)
    return found
end
