local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local frameworks = path.join(workspace.sdk(), "System", "Library", "Frameworks")

local function header(framework, name)
    return io.readfile(path.join(frameworks, framework .. ".framework", "Headers", name))
end

local function source(relative)
    return io.readfile(path.join(backports, relative))
end

local function missing_in(text, needles)
    for _, needle in ipairs(needles) do
        if not text:find(needle, 1, true) then
            return needle
        end
    end
    return nil
end

local CASES = {
    {
        label = "AVAudioSessionPortDescription data sources",
        sdk = {
            {"AVFAudio", "AVAudioSessionRoute.h", {
                "*selectedDataSource API_AVAILABLE(ios(7.0)",
                "setPreferredDataSource:(nullable AVAudioSessionDataSourceDescription *)dataSource error:(NSError **)outError API_AVAILABLE(ios(7.0)",
            }},
            {"AVFAudio", "AVAudioSession.h", {
                "*inputDataSource API_AVAILABLE(ios(6.0)",
                "setInputDataSource:(nullable AVAudioSessionDataSourceDescription *)dataSource error:(NSError **)outError API_AVAILABLE(ios(6.0)",
            }},
        },
        source = "src/AVFAudio/AVAudioSessionPortDescription7.m",
        mutation = {"setInputDataSource:dataSource error:outError", "setInputDataSource:nil error:outError"},
        needles = {
            "- (NSArray<AVAudioSessionDataSourceDescription *> *)dataSources",
            "- (AVAudioSessionDataSourceDescription *)selectedDataSource",
            "- (BOOL)setPreferredDataSource:(AVAudioSessionDataSourceDescription *)dataSource error:(NSError **)outError",
            "[[AVAudioSession sharedInstance] setInputDataSource:dataSource error:outError]",
        },
    },
    {
        label = "UIResponder textInputMode",
        sdk = {
            {"UIKit", "UIResponder.h", {
                "*textInputMode API_AVAILABLE(ios(7.0))",
            }},
            {"UIKit", "UITextInput.h", {
                "+ (nullable UITextInputMode *)currentInputMode API_DEPRECATED(",
            }},
        },
        source = "src/UIKit/UIResponder+TextInput7.m",
        mutation = {"return [UITextInputMode currentInputMode];", "return nil;"},
        needles = {
            "- (UITextInputMode *)textInputMode",
            "return [UITextInputMode currentInputMode];",
        },
    },
    {
        label = "MTLDrawable presented handlers",
        sdk = {
            {"Metal", "MTLDrawable.h", {
                "- (void)addPresentedHandler:(MTLDrawablePresentedHandler)block API_AVAILABLE(macos(10.15.4), ios(10.3), macCatalyst(13.4));",
            }},
        },
        source = "src/Metal/RevenantMetalDrawable.m",
        mutation = {"handler((id<MTLDrawable>)self);", "(void)self;"},
        needles = {
            "- (void)addPresentedHandler:(MTLDrawablePresentedHandler)block",
            "[_presentedHandlers addObject:block];",
            "handler((id<MTLDrawable>)self);",
            "_drawableID = __sync_add_and_fetch(&revenant_drawable_counter, 1);",
            "_presentedTime = CACurrentMediaTime();",
        },
    },
    {
        label = "CLGeocoder postal address",
        sdk = {
            {"CoreLocation", "CLGeocoder.h", {
                "- (void)geocodePostalAddress:(CNPostalAddress *)postalAddress completionHandler:",
                "- (void)geocodeAddressDictionary:(NSDictionary *)addressDictionary completionHandler:",
            }},
        },
        source = "src/CoreLocation/CLGeocoder+PostalAddress11.m",
        mutation = {"geocodeAddressDictionary:[RevenantContacts", "geocodeAddressString:[RevenantContacts"},
        needles = {
            "- (void)geocodePostalAddress:(CNPostalAddress *)postalAddress completionHandler:",
            "- (void)geocodePostalAddress:(CNPostalAddress *)postalAddress preferredLocale:(NSLocale *)locale completionHandler:",
            "[self geocodeAddressDictionary:[RevenantContacts addressBookAddressWithPostalAddress:postalAddress] completionHandler:completionHandler]",
        },
        mapping = {"src/Contacts/RevenantContactsMapping.m", {
            "+ (NSDictionary *)addressBookAddressWithPostalAddress:(CNPostalAddress *)address",
        }},
    },
}

local function problem(case, text)
    for _, sdk in ipairs(case.sdk) do
        local needle = missing_in(header(sdk[1], sdk[2]), sdk[3])
        if needle then
            return case.label .. " SDK " .. sdk[2] .. " does not contain " .. needle
        end
    end
    local needle = missing_in(text, case.needles)
    if needle then
        return case.label .. " backport " .. case.source .. " does not contain " .. needle
    end
    if case.mapping then
        needle = missing_in(source(case.mapping[1]), case.mapping[2])
        if needle then
            return case.label .. " mapping " .. case.mapping[1] .. " does not contain " .. needle
        end
    end
    return nil
end

local function broken_text(case)
    local text = source(case.source)
    local start, stop = text:find(case.mutation[1], 1, true)
    assert(start, case.label .. " has no " .. case.mutation[1] .. " for the negative control")
    return text:sub(1, start - 1) .. case.mutation[2] .. text:sub(stop + 1)
end

function main()
    for _, case in ipairs(CASES) do
        local found = problem(case, source(case.source))
        assert(not found, found)
        local broken = problem(case, broken_text(case))
        assert(broken, "the negative control for " .. case.label .. " passed a broken backport")
    end
end
