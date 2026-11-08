local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

function sdk_interface(sdk, module)
    local files = os.files(path.join(sdk, "usr", "lib", "swift", module .. ".swiftmodule", "*-apple-ios.swiftinterface"))
    byteorder.sort(files)
    return files[1]
end

function interface_blocks(interface, opening)
    local blocks, current = {}, nil
    for line in (io.readfile(interface) .. "\n"):gmatch("([^\n]*)\n") do
        if current then
            table.insert(current, line)
            if line == "}" then
                table.insert(blocks, table.concat(current, "\n"))
                current = nil
            end
        elseif line == opening then
            current = {line}
        end
    end
    return blocks
end
