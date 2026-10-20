local MEMBERS = {
    {"- (void)setRelevantShortcuts:(NSArray<INRelevantShortcut *> *)shortcuts", "INRelevantShortcutStore -setRelevantShortcuts:completionHandler:"},
    {"- (void)getAllVoiceShortcutsWithCompletion:", "INVoiceShortcutCenter -getAllVoiceShortcutsWithCompletion:"},
    {"- (void)getVoiceShortcutWithIdentifier:(NSUUID *)identifier", "INVoiceShortcutCenter -getVoiceShortcutWithIdentifier:completion:"},
}

local function body_of(source, definition)
    local start = source:find("\n" .. definition, 1, true)
    if not start then
        return nil
    end
    local finish = source:find("\n@end", start, true)
    return source:sub(start, (finish or #source + 1) - 1)
end

function main(file)
    local source = io.readfile(file, {encoding = "binary"})
    local failures, passed = {}, 0
    for _, member in ipairs(MEMBERS) do
        local definition, row = member[1], member[2]
        local body = body_of(source, definition)
        if not body then
            table.insert(failures, row .. ": the method is not in the object at all")
        else
            local brace = body:find("{", 1, true)
            if not brace then
                raise("%s: the body has no opening brace", row)
            end
            local dispatch = body:find("dispatch_async(", brace, true)
            if not dispatch then
                table.insert(failures, row .. ": no dispatch at all, so the handler is called inline")
            elseif body:sub(brace, dispatch - 1):find("completionHandler(", 1, true) then
                table.insert(failures, row .. ": the handler is called BEFORE the dispatch")
            else
                passed = passed + 1
                print(string.format("intents12 port %-56s dispatches its handler", row))
            end
        end
    end
    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("port bodies: %d of %d dispatch, %d failed", passed, #MEMBERS, #failures))
    if #failures > 0 then
        os.exit(1)
    end
end
