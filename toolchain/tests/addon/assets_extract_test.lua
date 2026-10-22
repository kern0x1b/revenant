import("core.base.json")

local function run(tool, folder, arguments)
    local out, err = path.join(folder, "stdout.txt"), path.join(folder, "stderr.txt")
    local code = os.execv(tool, arguments, {try = true, stdout = out, stderr = err})
    return code, io.readfile(out) or "", io.readfile(err) or ""
end

local function plist(file)
    return json.decode(os.iorunv("plutil", {"-convert", "json", "-o", "-", file}))
end

local function extraction(tool, folder, catalogue, check)
    local output = path.join(folder, "extracted")
    local code, out = run(tool, folder, {catalogue, output})
    check(code == 0 and out:find(" images of ", 1, true) ~= nil, "a catalogue is extracted")
    local listing = json.decode(os.iorunv("assetutil", {"--info", catalogue}))
    local index = plist(path.join(output, "AssetCatalogImages.plist"))
    local count = 0
    for _ in pairs(index) do
        count = count + 1
    end
    local icons = plist(path.join(output, "AssetCatalogIcons.plist"))
    local missing, seen = {}, {}
    for position, row in ipairs(listing) do
        if position > 1 and row.AssetType == "Image" and not row.Name:startswith("ZZZZ") and index[row.Name] == nil and icons[row.Name] == nil
            and not seen[row.Name] then
            seen[row.Name] = true
            table.insert(missing, row.Name)
        end
    end
    table.sort(missing)
    check(#missing == 0, "every image the catalogue names is extracted: " .. table.concat(missing, " ", 1, math.min(#missing, 5)))
    local packed = false
    for _, entry in ipairs(os.filedirs(path.join(output, "**"))) do
        packed = packed or path.filename(entry):find("ZZZZPackedAsset", 1, true) ~= nil
    end
    check(not packed, "no atlas comes out as an image")
    local first, all_there, kinds = nil, true, true
    local scales = {[1] = true, [2] = true, [3] = true}
    local idioms = {universal = true, phone = true, pad = true}
    local images = path.join(output, "AssetCatalogImages.plist")
    local order = {}
    for name in io.readfile(images):gmatch("\n\t<key>([^<]*)</key>") do
        table.insert(order, name)
    end
    check(#order == count, string.format("the image plist names %d images at its top level, and %d were read in its order", count, #order))
    for _, name in ipairs(order) do
        for _, variant in ipairs(index[name] or {}) do
            first = first or variant
            all_there = all_there and os.isfile(path.join(output, variant.file))
            kinds = kinds and scales[variant.scale] == true and idioms[variant.idiom] == true
        end
    end
    check(first ~= nil and all_there, "every file the plist names is there")
    if first then
        local sizes = os.iorunv("sips", {"-g", "pixelWidth", "-g", "pixelHeight", path.join(output, first.file)})
        check(sizes:find(string.format("%d", first.width), 1, true) ~= nil and sizes:find(string.format("%d", first.height), 1, true) ~= nil,
              "the plist gives the pixel size of the file")
    end
    check(kinds, "only the scales and idioms of iOS 6 and the later ones asked for")
end

function failures(opt)
    local found = {}
    if not is_host("macosx") or not os.isdir("/System/Library/PrivateFrameworks/CoreUI.framework") then
        print("assets_extract_test: skipped, assets-extract needs a Mac with CoreUI")
        return found
    end
    local function check(condition, name)
        if not condition then
            table.insert(found, name)
        end
    end
    local revenant = path.directory(path.absolute(opt.modules))
    local workspace = import("workspace", {rootdir = opt.modules, anonymous = true})
    local tool = import("assets_extract", {rootdir = path.join(revenant, "tools", "assets_extract"), anonymous = true}).tool()
    local folder = workspace.fresh("assets-extract-test")
    check(run(tool, folder, {}) == 64, "no arguments is a bad command line")
    local not_catalogue = path.join(folder, "Assets.car")
    io.writefile(not_catalogue, "not a catalogue")
    local code, _, err = run(tool, folder, {not_catalogue, path.join(folder, "out")})
    check(code == 65 and err:find("not a compiled asset catalogue", 1, true) ~= nil, "a file that is not a catalogue is refused")
    local catalogue = os.getenv("REVENANT_TEST_ASSET_CATALOGUE")
    if catalogue and catalogue ~= "" and os.isfile(catalogue) then
        extraction(tool, folder, catalogue, check)
    else
        print("assets_extract_test: skipped the extraction of a catalogue: name one in REVENANT_TEST_ASSET_CATALOGUE")
    end
    os.tryrm(folder)
    return found
end
