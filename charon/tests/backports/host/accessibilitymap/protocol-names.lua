-- The generated protocol sources for this library's implemented protocol rows, written by
-- modules/apple/backports.lua's own protocol_sources() - the same function the build calls, with the
-- same argument order - and their paths printed, one per line, for the caller to compile.
--
-- The NAMES come from the registry too, in protocol-check.sh, with python3. They do not come from here:
-- a lua json read in this environment returned zero rows and said nothing about it, which is the shape of
-- check that examines nothing, and a check that examines nothing is what this file's companion check was
-- caught being last time.
function main(root, outdir, modules)
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    for _, library in ipairs(backports.libraries()) do
        if library.folder == "Accessibility" then
            local written = backports.protocol_sources({root = root}, library, outdir, library.folder)
            print("generated " .. #written .. " protocol source(s)")
            for _, file in ipairs(written) do print(path.filename(file)) end
        end
    end
end
