local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local FOLDER = "var/lib/revenant/tessdata"

local CODES = {
    "eng", "fra", "ita", "deu", "spa", "por", "chi_sim", "chi_tra", "kor", "jpn", "rus", "ukr", "tha", "vie", "ara",
    "tur", "ind", "ces", "dan", "nld", "nor", "msa", "pol", "ron", "swe", "fin", "hin", "mar",
}

local function known(code)
    return table.contains(CODES, code)
end

function installed(root)
    local license = path.join(root, "licenses", "LICENSE")
    if not os.isfile(license) then
        raise("%s is not installed, so the Vision text models cannot be packaged; the tessdata package installs it", license)
    end
    local models = {}
    for _, level in ipairs({"fast", "best"}) do
        local files = os.files(path.join(root, "share", "tessdata", level, "*.traineddata"))
        byteorder.sort(files)
        for _, file in ipairs(files) do
            local code = path.filename(file):match("^(.+)%.traineddata$")
            if not known(code) then
                raise("%s is not a Vision text model, so it has no place in the package", file)
            end
            table.insert(models, {source = file, destination = path.join(FOLDER, level, path.filename(file))})
        end
    end
    return {models = models, license = license}
end
