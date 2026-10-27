local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local FOLDER = "usr/share/revenant/tessdata"
local ARCHITECTURE = "iphoneos-arm"
local FAST_PACKAGE = "org.revenant.vision-text-fast"
local FAST_CODES = {"eng", "fra", "ita", "deu", "spa", "por"}

local LANGUAGES = {
    {code = "eng", package = "en", identifiers = {"en-US"}},
    {code = "fra", package = "fr", identifiers = {"fr-FR"}},
    {code = "ita", package = "it", identifiers = {"it-IT"}},
    {code = "deu", package = "de", identifiers = {"de-DE"}},
    {code = "spa", package = "es", identifiers = {"es-ES"}},
    {code = "por", package = "pt", identifiers = {"pt-BR"}},
    {code = "chi_sim", package = "zh-hans", identifiers = {"zh-Hans", "yue-Hans"}},
    {code = "chi_tra", package = "zh-hant", identifiers = {"zh-Hant", "yue-Hant"}},
    {code = "kor", package = "ko", identifiers = {"ko-KR"}},
    {code = "jpn", package = "ja", identifiers = {"ja-JP"}},
    {code = "rus", package = "ru", identifiers = {"ru-RU"}},
    {code = "ukr", package = "uk", identifiers = {"uk-UA"}},
    {code = "tha", package = "th", identifiers = {"th-TH"}},
    {code = "vie", package = "vi", identifiers = {"vi-VT"}},
    {code = "ara", package = "ar", identifiers = {"ar-SA", "ars-SA"}},
    {code = "tur", package = "tr", identifiers = {"tr-TR"}},
    {code = "ind", package = "id", identifiers = {"id-ID"}},
    {code = "ces", package = "cs", identifiers = {"cs-CZ"}},
    {code = "dan", package = "da", identifiers = {"da-DK"}},
    {code = "nld", package = "nl", identifiers = {"nl-NL"}},
    {code = "nor", package = "no", identifiers = {"no-NO", "nn-NO", "nb-NO"}},
    {code = "msa", package = "ms", identifiers = {"ms-MY"}},
    {code = "pol", package = "pl", identifiers = {"pl-PL"}},
    {code = "ron", package = "ro", identifiers = {"ro-RO"}},
    {code = "swe", package = "sv", identifiers = {"sv-SE"}},
    {code = "fin", package = "fi", identifiers = {"fi-FI"}},
    {code = "hin", package = "hi", identifiers = {"hi-IN"}},
    {code = "mar", package = "mr", identifiers = {"mr-IN"}},
}

local function package_of(language)
    return "org.revenant.vision-text-" .. language.package
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

function fast_codes()
    return FAST_CODES
end

function fast_package()
    return FAST_PACKAGE
end

function recommended()
    return {"org.revenant.vision-text-en", "org.revenant.vision-text-ru", "org.revenant.vision-text-uk"}
end

function write(opt)
    local share = path.join(opt.root, "share", "tessdata")
    local license = path.join(opt.root, "licenses", "LICENSE")
    local commits = pins()
    local written = {}
    local fast_files = {}
    for _, code in ipairs(FAST_CODES) do
        table.insert(fast_files, path.join(share, "fast", code .. ".traineddata"))
    end
    table.insert(written, write_package({
        name = FAST_PACKAGE, title = "Vision text fast models", level = "fast", files = fast_files, license = license,
        version = version(commits.fast), outputdir = opt.outputdir, workdir = path.join(opt.workdir, "fast"),
        description = "the tessdata_fast models of Vision's fast text recognition for en-US, fr-FR, it-IT, de-DE, es-ES and pt-BR, in /" .. FOLDER .. "/fast; the Backports library of Vision depends on it",
    }))
    for _, language in ipairs(LANGUAGES) do
        table.insert(written, write_package({
            name = package_of(language), title = "Vision text " .. language.package, level = "best",
            files = {path.join(share, "best", language.code .. ".traineddata")}, license = license,
            version = version(commits.best), outputdir = opt.outputdir, workdir = path.join(opt.workdir, language.package),
            description = "the tessdata_best model " .. language.code .. " of Vision's accurate text recognition for " .. table.concat(language.identifiers, ", ") .. ", in /" .. FOLDER .. "/best",
        }))
    end
    return written
end
