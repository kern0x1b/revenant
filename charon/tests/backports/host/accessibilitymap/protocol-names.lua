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
