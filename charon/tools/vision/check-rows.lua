-- Ask the registry's own reader whether every member Vision130.m defines has an entry, using the
-- project's own entry_of rather than a copy of it.
import("apple.backports", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
local backports = import("apple.backports", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
local root = os.getenv("REGISTRY_ROOT")
-- registry() reads the generated layer as it is on disk: write it first
backports.generate(root)
local listed = backports.registry(root)
print("registry read: " .. table.concat(table.orderkeys(listed), " "))
local members = {}
for line in io.lines(os.getenv("MEMBERS")) do
    if line ~= "" then members[#members + 1] = line end
end
local unlisted, own, viaclass = {}, 0, 0
for _, api in ipairs(members) do
    local entry = backports.entry_of(listed, api, nil)
    if not entry then
        unlisted[#unlisted + 1] = api
    elseif entry.api == api then
        own = own + 1
    else
        viaclass = viaclass + 1
    end
end
print(("members checked: %d | answered by a row of their own: %d | answered by another row: %d | UNANSWERED: %d")
    :format(#members, own, viaclass, #unlisted))
for _, api in ipairs(unlisted) do print("  unlisted: " .. api) end
