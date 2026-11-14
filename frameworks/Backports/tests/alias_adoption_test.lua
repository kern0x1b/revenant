local backports = path.absolute(path.join(os.scriptdir(), ".."))
local root = path.absolute(path.join(backports, "..", ".."))

local REQUIRED = {
    {framework = "Foundation", class = "NSURLComponents", protocols = {"NSCopying"}},
    {framework = "Foundation", class = "NSURLQueryItem", protocols = {"NSSecureCoding", "NSCopying"}},
    {framework = "Foundation", class = "NSUUID", protocols = {"NSCopying", "NSSecureCoding"}},
}

local function listed(source)
    local found = {}
    for _, file in ipairs(os.files(path.join(source, "**.m"))) do
        local framework = path.filename(path.directory(file))
        for name, protocols in (io.readfile(file) or ""):gmatch("REVENANT_ALIAS_ADOPTS%(([%w_]+),%s*([^)]*)%)") do
            local entry = {framework = framework, class = name, protocols = {}}
            for protocol in protocols:gmatch("[%w_]+") do
                table.insert(entry.protocols, protocol)
            end
            table.insert(found, entry)
        end
    end
    return found
end

local function adopted(library)
    local text = os.iorunv("xcrun", {"otool", "-arch", "armv7", "-ov", library})
    local found, current = {}, nil
    for line in text:gmatch("[^\n]+") do
        local class = line:match("^        baseProtocols%s+0x%x+ __OBJC_CLASS_PROTOCOLS_%$_Revenant([%w_]+)%(")
        if class then
            current = class
            found[current] = found[current] or {}
        elseif current then
            local protocol = line:match("^            list%[%d+%]%s+0x%x+ __OBJC_PROTOCOL_%$_([%w_]+)$")
            if protocol then
                found[current][protocol] = true
            elseif line:match("^        %S") then
                current = nil
            end
        end
    end
    return found
end

function main()
    local folder = os.getenv("REVENANT_ALIAS_LIBRARIES") or path.join(root, "build", "iphoneos", "armv7", "release")
    local entries = listed(path.join(backports, "src"))
    for _, required in ipairs(REQUIRED) do
        local present = false
        for _, entry in ipairs(entries) do
            if entry.class == required.class then
                present = true
                for _, protocol in ipairs(required.protocols) do
                    assert(table.contains(entry.protocols, protocol), "REVENANT_ALIAS_ADOPTS(" .. required.class .. ") does not list " .. protocol)
                end
            end
        end
        assert(present, "no REVENANT_ALIAS_ADOPTS names " .. required.class .. ", so the Swift runtime cannot check its generic requirements")
    end
    local libraries, errors = {}, {}
    for _, entry in ipairs(entries) do
        local library = path.join(folder, "lib" .. entry.framework .. "Backports.dylib")
        assert(os.isfile(library), library .. " is not built: build the Backports component first")
        libraries[library] = libraries[library] or adopted(library)
        local found = libraries[library][entry.class]
        for _, protocol in ipairs(entry.protocols) do
            if not (found and found[protocol]) then
                table.insert(errors, string.format("%s: Revenant%s does not carry the protocol %s", path.filename(library), entry.class, protocol))
            end
        end
    end
    assert(#errors == 0, table.concat(errors, "\n"))
    print("alias adoption: %d classes carry the protocols their source lists", #entries)
end
