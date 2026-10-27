local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local FOLDER = "usr/share/revenant/tessdata"
local ARCHITECTURE = "iphoneos-arm"
local PREFIX = "org.revenant.vision-text-"
local DEPENDS = {PREFIX .. "fast-eng"}
local RECOMMENDS = {PREFIX .. "fast-rus", PREFIX .. "fast-ukr"}

local LANGUAGES = {
    {code = "eng", identifiers = {"en-US"}},
    {code = "fra", identifiers = {"fr-FR"}},
    {code = "ita", identifiers = {"it-IT"}},
    {code = "deu", identifiers = {"de-DE"}},
    {code = "spa", identifiers = {"es-ES"}},
    {code = "por", identifiers = {"pt-BR"}},
    {code = "chi_sim", identifiers = {"zh-Hans", "yue-Hans"}},
    {code = "chi_tra", identifiers = {"zh-Hant", "yue-Hant"}},
    {code = "kor", identifiers = {"ko-KR"}},
    {code = "jpn", identifiers = {"ja-JP"}},
    {code = "rus", identifiers = {"ru-RU"}},
    {code = "ukr", identifiers = {"uk-UA"}},
    {code = "tha", identifiers = {"th-TH"}},
    {code = "vie", identifiers = {"vi-VT"}},
    {code = "ara", identifiers = {"ar-SA", "ars-SA"}},
    {code = "tur", identifiers = {"tr-TR"}},
    {code = "ind", identifiers = {"id-ID"}},
    {code = "ces", identifiers = {"cs-CZ"}},
    {code = "dan", identifiers = {"da-DK"}},
    {code = "nld", identifiers = {"nl-NL"}},
    {code = "nor", identifiers = {"no-NO", "nn-NO", "nb-NO"}},
    {code = "msa", identifiers = {"ms-MY"}},
    {code = "pol", identifiers = {"pl-PL"}},
    {code = "ron", identifiers = {"ro-RO"}},
    {code = "swe", identifiers = {"sv-SE"}},
    {code = "fin", identifiers = {"fi-FI"}},
    {code = "hin", identifiers = {"hi-IN"}},
    {code = "mar", identifiers = {"mr-IN"}},
}

local function language_of(code)
    for _, language in ipairs(LANGUAGES) do
        if language.code == code then
            return language
        end
    end
end

local function package_of(level, code)
    return PREFIX .. level .. "-" .. (code:gsub("_", "-"))
end

local function version(commit)
    return "1.0+" .. commit:sub(1, 8)
end

local function pins()
    local recipe = path.join(os.scriptdir(), "..", "..", "..", "packages", "t", "tessdata", "xmake.lua")
    local text = io.readfile(recipe)
    return {
        fast = assert(text:match('FAST_COMMIT = "(%x+)"'), "no FAST_COMMIT in " .. recipe),
        best = assert(text:match('BEST_COMMIT = "(%x+)"'), "no BEST_COMMIT in " .. recipe),
    }
end

local function write_package(opt)
    for _, file in ipairs(table.join(opt.files, {opt.license})) do
        if not os.isfile(file) then
            raise("%s is not installed, so %s cannot be packaged; the tessdata package installs it", file, opt.name)
        end
    end
    local tree = path.join(opt.workdir, "tree")
    os.tryrm(opt.workdir)
    os.mkdir(path.join(tree, FOLDER, opt.level))
    for _, file in ipairs(opt.files) do
        os.cp(file, path.join(tree, FOLDER, opt.level, path.filename(file)))
    end
    local documents = path.join(tree, "usr", "share", "doc", opt.name)
    os.mkdir(documents)
    os.cp(opt.license, path.join(documents, "LICENSE"))
    local control = path.join(opt.workdir, "control")
    io.writefile(control, table.concat({
        "Package: " .. opt.name,
        "Name: " .. opt.title,
        "Architecture: " .. ARCHITECTURE,
        "Section: System",
        "Description: " .. opt.description,
    }, "\n") .. "\n")
    local deb = debian.write({control = control, version = opt.version, root = tree, outputdir = opt.outputdir})
    os.tryrm(opt.workdir)
    return deb
end

function languages()
    return LANGUAGES
end

function depends()
    return table.copy(DEPENDS)
end

function recommended()
    return table.copy(RECOMMENDS)
end

function write(opt)
    local share = path.join(opt.root, "share", "tessdata")
    local license = path.join(opt.root, "licenses", "LICENSE")
    local commits = pins()
    local written = {}
    for _, level in ipairs({"fast", "best"}) do
        local files = os.files(path.join(share, level, "*.traineddata"))
        table.sort(files)
        for _, file in ipairs(files) do
            local code = path.filename(file):match("^(.+)%.traineddata$")
            local language = language_of(code)
            if not language then
                raise("%s is not a Vision text model, so it has no package", file)
            end
            local name = package_of(level, code)
            local description
            if level == "fast" then
                description = "the tessdata_fast model " .. code .. " of Vision's fast text recognition, in /" .. FOLDER .. "/fast"
            else
                description = "the tessdata_best model " .. code .. " of Vision's accurate text recognition for " .. table.concat(language.identifiers, ", ") .. ", in /" .. FOLDER .. "/best"
            end
            table.insert(written, write_package({
                name = name, title = "Vision text " .. level .. " " .. code, level = level, files = {file}, license = license,
                version = version(commits[level]), outputdir = opt.outputdir, workdir = path.join(opt.workdir, name),
                description = description,
            }))
        end
    end
    return written
end
