local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

function failures(arguments)
    local source = path.join(os.scriptdir(), "sincospif.c")
    local implementation = path.join(os.scriptdir(), "..", "..", "src", "apple-compat", "src")
    local headers = path.join(os.scriptdir(), "..", "..", "src", "apple-compat", "include")
    local output = workspace.run("apple-compat-sincospif")
    os.rm(output)
    os.mkdir(output)
    local probe = path.join(output, "simd_probe.cpp")
    io.writefile(probe, "#include <simd/math.h>\nint main() { return 0; }\n")
    local vfs = lowered.overlay(arguments.sdk, path.join(output, "overlay"))
    local probe_args = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot", "-isysroot", arguments.sdk,
                        "-x", "c++", "-c", probe, "-o", path.join(output, "before.o")}
    local before_log = path.join(output, "before.log")
    local before = os.execv(arguments.clang, probe_args, {try = true, stdout = before_log, stderr = before_log})
    local diagnostic = io.readfile(before_log) or ""
    if before == 0 or not diagnostic:find("no member named '__sincospif' in the global namespace", 1, true) then
        return {"the armv7 iOS 6 SIMD probe did not reproduce the __sincospif declaration failure: " .. diagnostic}
    end
    local after_args = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot", "-isysroot", arguments.sdk,
                        "-ivfsoverlay", vfs, "-I" .. lowered.include_directory(path.join(output, "overlay")),
                        "-x", "c++", "-c", probe, "-o", path.join(output, "after.o")}
    local after_log = path.join(output, "after.log")
    local after = os.execv(arguments.clang, after_args, {try = true, stdout = after_log, stderr = after_log})
    if after ~= 0 then
        return {"the armv7 iOS 6 SIMD probe still fails with the lowered math header: " .. (io.readfile(after_log) or "")}
    end
    local archive_probe = path.join(output, "secure_archive.m")
    io.writefile(archive_probe, "#import <Foundation/Foundation.h>\nNSData *archive(id value) { return [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:NO error:0]; }\n")
    local archive_args = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", arguments.sdk,
                          "-fobjc-arc", "-Werror=unguarded-availability-new", "-fsyntax-only", archive_probe}
    local archive_before_log = path.join(output, "archive-before.log")
    local archive_before = os.execv(arguments.clang, archive_args, {try = true, stdout = archive_before_log, stderr = archive_before_log})
    local archive_diagnostic = io.readfile(archive_before_log) or ""
    if archive_before == 0 or not archive_diagnostic:find("only available on iOS 11.0 or newer", 1, true) then
        return {"the armv7 iOS 6 secure archive probe did not reproduce its availability failure: " .. archive_diagnostic}
    end
    local archive_after_args = table.join(archive_args, {"-ivfsoverlay", vfs, "-I" .. lowered.include_directory(path.join(output, "overlay"))})
    local archive_after_log = path.join(output, "archive-after.log")
    local archive_after = os.execv(arguments.clang, archive_after_args, {try = true, stdout = archive_after_log, stderr = archive_after_log})
    if archive_after ~= 0 then
        return {"the armv7 iOS 6 secure archive probe still fails with lowering: " .. (io.readfile(archive_after_log) or "")}
    end
    local attachment_probe = path.join(output, "attachment.m")
    io.writefile(attachment_probe, "#import <UIKit/UIKit.h>\nid attachmentProbe(void) { return NSAttachmentAttributeName; }\nNSTextAttachment *textAttachmentProbe(void) { return [NSTextAttachment new]; }\n")
    local attachment_args = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", arguments.sdk,
                             "-fobjc-arc", "-Werror=unguarded-availability-new", "-fsyntax-only", attachment_probe}
    local attachment_before_log = path.join(output, "attachment-before.log")
    local attachment_before = os.execv(arguments.clang, attachment_args, {try = true, stdout = attachment_before_log, stderr = attachment_before_log})
    local attachment_diagnostic = io.readfile(attachment_before_log) or ""
    if attachment_before == 0 or not attachment_diagnostic:find("only available on iOS 7.0 or newer", 1, true) then
        return {"the armv7 iOS 6 attachment probe did not reproduce its availability failure: " .. attachment_diagnostic}
    end
    local attachment_after_args = table.join(attachment_args, {"-ivfsoverlay", vfs, "-I" .. lowered.include_directory(path.join(output, "overlay"))})
    local attachment_after_log = path.join(output, "attachment-after.log")
    local attachment_after = os.execv(arguments.clang, attachment_after_args, {try = true, stdout = attachment_after_log, stderr = attachment_after_log})
    if attachment_after ~= 0 then
        return {"the armv7 iOS 6 attachment probe still fails with lowering: " .. (io.readfile(attachment_after_log) or "")}
    end
    local executable = path.join(output, "sincospif")
    local log = path.join(output, "build.log")
    local test_object = path.join(output, "sincospif_test.o")
    local float_object = path.join(output, "__sincospif.o")
    local double_object = path.join(output, "__sincospi.o")
    local compile_commands = {
        {"-O2", "-fno-builtin", "-c", source, "-o", test_object},
        {"-O2", "-fno-builtin", "-I" .. headers, "-D__IPHONE_OS_VERSION_MIN_REQUIRED=60000", "-D__sincospif=revenant_sincospif",
         "-D__sinpif=revenant_sinpif", "-D__cospif=revenant_cospif", "-D__tanpif=revenant_tanpif",
         "-c", path.join(implementation, "__sincospif.c"), "-o", float_object},
        {"-O2", "-fno-builtin", "-I" .. headers, "-D__IPHONE_OS_VERSION_MIN_REQUIRED=60000", "-D__sincospi=revenant_sincospi",
         "-D__sinpi=revenant_sinpi", "-D__cospi=revenant_cospi", "-D__tanpi=revenant_tanpi",
         "-c", path.join(implementation, "__sincospi.c"), "-o", double_object},
        {test_object, float_object, double_object, "-lm", "-o", executable}
    }
    for _, command in ipairs(compile_commands) do
        local built = os.execv("cc", command, {try = true, stdout = log, stderr = log})
        if built ~= 0 then
            return {"the host accuracy test did not compile: " .. (io.readfile(log) or "")}
        end
    end
    local ran = os.execv(executable, {}, {try = true, stdout = log, stderr = log, timeout = 120000})
    if ran ~= 0 then
        return {"the host dense sweep failed: " .. (io.readfile(log) or "")}
    end
    return {}
end
