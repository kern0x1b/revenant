import("core.base.json")

local failures, checks = 0, 0

local function expect(name, condition)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL " .. name)
    end
end

function main(cache, modules)
    local objc = import("objc", {rootdir = modules, anonymous = true})
    local backports = import("backports", {rootdir = modules, anonymous = true})
    local inventory = objc.inventory(cache)
    local nothing = {classes = {}, members = {}, symbols = {}, registered = {}, answered = {}}

    local function verdict(entries, deployment)
        local root = os.tmpfile() .. ".registry"
        os.mkdir(path.join(root, "registry"))
        io.writefile(path.join(root, "registry", "probe.json"), json.encode(entries))
        local message = ""
        try {
            function ()
                backports.check_registry(root, nothing, false, deployment, {}, inventory)
            end,
            catch {
                function (errors)
                    message = tostring(errors)
                end
            }
        }
        os.rm(root)
        return message
    end

    local function absent(api, extra)
        return table.join2({api = api, kind = "method", introduced = "11.0", status = "absent", reason = "probe", effect = "probe"}, extra or {})
    end
    local function ignored(api, extra)
        return table.join2({api = api, kind = "method", introduced = "11.0", status = "ignored", facts = "facts/probe.md", effect = "probe"}, extra or {})
    end

    local real = "-[UINavigationItem backButtonTitle]"
    expect("an absent entry the release carries is refused", verdict({absent(real)}, "6.1.3"):find("carries it itself", 1, true) ~= nil)
    expect("the refusal names it", verdict({absent(real)}, "6.1.3"):find(real, 1, true) ~= nil)
    expect("a property is held to its accessors", verdict({absent("UINavigationItem.backButtonTitle", {kind = "property"})}, "6.1.3"):find("carries it itself", 1, true) ~= nil)
    expect("a class the release has is refused", verdict({absent("UINavigationItem", {kind = "class"})}, "6.1.3"):find("carries it itself", 1, true) ~= nil)
    expect("an absent entry the release lacks passes", verdict({absent("-[UINavigationItem charonNoSuchSelector]")}, "6.1.3") == "")
    expect("an entry that stops at a release where it is native passes", verdict({absent(real, {maximum = "6.0"})}, "6.1.3") == "")
    expect("an entry the release has natively passes", verdict({absent(real, {introduced = "5.0"})}, "6.1.3") == "")
    expect("an entry that starts after the release passes", verdict({absent(real, {minimum = "7.0"})}, "6.1.3") == "")
    expect("an ignored entry the release carries passes", verdict({ignored(real)}, "6.1.3") == "")
    expect("an ignored entry the release lacks is refused", verdict({ignored("-[UINavigationItem charonNoSuchSelector]")}, "6.1.3"):find("the release does not", 1, true) ~= nil)
    expect("a class method is looked up as a class method", verdict({absent("+[NSJSONSerialization dataWithJSONObject:options:error:]")}, "6.1.3"):find("carries it itself", 1, true) ~= nil)
    expect("an instance method is not taken for a class method", verdict({absent("+[UINavigationItem backButtonTitle]")}, "6.1.3") == "")

    print(string.format("%d checks, %d failures", checks, failures))
    if failures > 0 then
        raise("the registry check does not hold")
    end
end
