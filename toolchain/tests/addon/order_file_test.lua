import("fixtures")

local SOURCE = [[
int hot(int x) { return x * 3 + 1; }
int cold(int x) { return x - 7; }
int main(int argc, char **argv) { return hot(argc) == 4 ? 0 : 1; }
]]

local TEXT_BASE = 0x4000

local HEADER = "pid\tentry\tthumb\tcycles\truns\tticks\texact_runs\texact_ticks\tchained_runs\tshort_runs\tunknown_runs\timage\toffset\n"

local function row(address, ticks, image)
    local offset = string.format("0x%08x", address - TEXT_BASE)
    return table.concat({"1", string.format("0x%08x", address), "0", "5", "10", tostring(ticks), "10", tostring(ticks), "0", "0", "0", image, offset}, "\t") .. "\n"
end

local function symbol_address(folder, nm, name)
    for line in fixtures.run(folder, nm, {"-n", "bench"}):gmatch("[^\n]+") do
        local address, kind, found = line:match("^(%x+) (%a) (%S+)$")
        if found == name and (kind == "T" or kind == "t") then
            return tonumber(address, 16)
        end
    end
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local bin = path.directory(opt.clang)
    local nm = path.join(bin, "llvm-nm")
    local objdump = path.join(bin, "llvm-objdump")
    for _, tool in ipairs({nm, objdump}) do
        if not os.isfile(tool) then
            table.insert(found, tool .. " is not in the llvm package: the libraries config installs llvm-nm and llvm-objdump with the llvm tools")
        end
    end
    if #found == 0 then
        io.writefile(path.join(folder, "prog.c"), SOURCE)
        fixtures.run(folder, opt.clang, {"-target", "armv7-apple-ios6.0", "-mcpu=cortex-a9", "-mfpu=neon", "-O2", "-isysroot", opt.sdk,
                                         "-Wno-incompatible-sysroot", "-w", "prog.c", "-o", "bench"})
        local hot = symbol_address(folder, nm, "_hot")
        local main = symbol_address(folder, nm, "_main")
        if not hot or not main then
            table.insert(found, "the test program has no _hot or _main in its text symbols")
        else
            local profile = HEADER .. row(hot, 900, "/usr/local/bin/bench") .. row(main, 40, "/usr/local/bin/bench")
                .. row(0x8000, 500, "/usr/lib/dyld")
            io.writefile(path.join(folder, "block-profile.tsv"), profile)
            local script = path.join(os.projectdir(), "toolchain", "tools", "order_file", "order_file.lua")
            fixtures.run(folder, os.programfile(), {"l", "-P", os.projectdir(), script, "--llvm-bin", bin,
                                                   path.join(folder, "block-profile.tsv"), path.join(folder, "bench"),
                                                   path.join(folder, "order.txt")})
            local order = io.readfile(path.join(folder, "order.txt"))
            if order ~= "_hot\n_main\n" then
                table.insert(found, "the order file must list the executed functions, hottest first, and nothing else; it is: " .. order:gsub("\n", " "))
            end
        end
    end
    os.tryrm(folder)
    return found
end
