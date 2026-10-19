local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

function main()
    local render = import("gen.render", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local index = {["UIAction.title"] = {}}
    local protocol_members = {["UIMenuLeaf.presentationSourceItem"] = true, ["NSObject.description"] = true}
    local conformances = {UIAction = {"UIMenuLeaf"}, UIMenuLeaf = {"NSObject"}}

    check(render.held("UIAction.presentationSourceItem", index, conformances, protocol_members),
          "a property a protocol the class conforms to declares is held")
    check(render.held("UIAction.title", index, conformances, protocol_members), "a class's own member is held")
    check(not render.held("UIAction.absent", index, conformances, protocol_members),
          "a member no class or protocol declares is not held")
    check(not render.held("UIButton.presentationSourceItem", index, conformances, protocol_members),
          "a class that does not conform to the protocol does not hold its member")
    check(render.held("UIAction.description", index, conformances, protocol_members),
          "a property of a protocol the protocol inherits is held, through the chain of conformances")
    check(not render.held("UIAction.presentationSourceItem", index, {}, protocol_members),
          "without the conformance the protocol's property is not held")

    print("held test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
