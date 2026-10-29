import("fixtures")

local SWIFT_FOUNDATION = {
    "NSDateInterval", "NSDimension", "NSISO8601DateFormatter", "NSMeasurement", "NSOrderedCollectionChange",
    "NSOrderedCollectionDifference", "NSPersonNameComponents", "NSPresentationIntent", "NSURLSessionWebSocketMessage",
    "NSUnitConverterLinear",
}

local CF_CHARACTER_SETS = {"User", "Password", "Host", "Path", "Query", "Fragment"}

local function attached(backports, project, folder, sources, frameworks)
    local added = {}
    local target = {
        name = function () return "app" end,
        get = function (_, key) return key == "frameworks" and frameworks or nil end,
        sourcefiles = function () return sources end,
        scriptdir = function () return folder end,
        pkg = function () return nil end,
        add = function (_, key, value) table.insert(added, key .. "=" .. value) end,
    }
    backports.attach(target, project)
    return added
end

function failures(opt)
    local backports = import("apple.backports", {rootdir = opt.modules, anonymous = true})
    local guards = import("apple.runtime_guards", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local app = path.join(folder, "app")
    local inside = path.join(folder, "frameworks", "Backports", "src", "Swift")
    os.mkdir(app)
    os.mkdir(inside)
    local swift = path.join(app, "main.swift")
    io.writefile(swift, "import Foundation\nprint(URLComponents())\n")
    local overlay = path.join(inside, "Overlay.swift")
    io.writefile(overlay, "import Foundation\n")
    local objc = path.join(app, "main.m")
    io.writefile(objc, "#import <Foundation/Foundation.h>\n")
    local required = {backports = {}}
    local project = {required_package = function (name) return required[name] end}

    local linked = attached(backports, project, app, {swift}, {})
    if not table.contains(linked, "packages=backports") then
        table.insert(found, "a Swift target that imports Foundation must take the backports package, not " .. table.concat(linked, ","))
    end
    local overlaid = attached(backports, project, inside, {overlay}, {})
    if table.contains(overlaid, "packages=backports") then
        table.insert(found, "a Swift target inside frameworks/Backports is built by the Backports, and must not take the package")
    end
    local plain = attached(backports, project, app, {objc}, {"Foundation"})
    if table.contains(plain, "packages=backports") then
        table.insert(found, "an Objective-C target links the Foundation framework, not libswiftFoundation, and must not take the package: " .. table.concat(plain, ","))
    end
    local unrequired = fixtures.refusal(function ()
        backports.attach({name = function () return "app" end, get = function () return nil end, sourcefiles = function () return {swift} end,
                          scriptdir = function () return app end, pkg = function () return nil end, add = function () end},
                         {required_package = function () return nil end})
    end) or ""
    if not unrequired:find("revenant@backports", 1, true) then
        table.insert(found, "a Swift target that imports Foundation in a project that does not require the package must be told to require it: " .. unrequired)
    end

    local table_of = guards.guards()["libswiftFoundation.dylib"] or {}
    for _, name in ipairs(SWIFT_FOUNDATION) do
        if not table_of["_OBJC_CLASS_$_" .. name] then
            table.insert(found, "apple.runtime_guards must record the weak import _OBJC_CLASS_$_" .. name .. " of libswiftFoundation")
        end
    end
    for _, name in ipairs(CF_CHARACTER_SETS) do
        local symbol = "__CFURLComponentsGetURL" .. name .. "AllowedCharacterSet"
        if not table_of[symbol] then
            table.insert(found, "apple.runtime_guards must record the weak import " .. symbol .. " of libswiftFoundation")
        end
    end

    os.tryrm(folder)
    return found
end
