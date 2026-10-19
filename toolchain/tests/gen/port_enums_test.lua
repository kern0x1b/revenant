local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local function row(cells)
    local out = {}
    for column = 1, 21 do
        out[column] = cells[column] or "-"
    end
    return out
end

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
end

local function run()
    local port = import("gen.port_enums", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local root = path.join(os.tmpdir(), "port-enums-test-" .. tostring(os.time()))
    local file = path.join(root, "port-values.tsv")
    write(file, "# triple=armv7-apple-ios6.1.3 (fixture)\n"
          .. "enumconst\tMetal\tc:@E@MTLStages@MTLStageAll\t2147483647\n"
          .. "enumtype\tMetal\tc:@E@MTLStages\tNSUInteger\n"
          .. "enumconst\tDispatch\tc:@Ea@DISPATCH_WALLTIME_NOW@DISPATCH_WALLTIME_NOW\t18446744073709551614\n"
          .. "enumtype\tDispatch\tc:@Ea@DISPATCH_WALLTIME_NOW\tunsigned long long\n"
          .. "enumconst\tDispatchIntrospection\tc:@Ea@DISPATCH_WALLTIME_NOW@DISPATCH_WALLTIME_NOW\t18446744073709551614\n"
          .. "enumconst\tFoundation\tc:@Ea@NSDateComponentUndefined@NSDateComponentUndefined\t2147483647\n"
          .. "unparsed\tBroken\t-\tBroken.h:1:1: error: fixture\n")
    local run_values = port.read(file)
    check(run_values.values["c:@E@MTLStages@MTLStageAll"] == "2147483647", "the run gives MTLStageAll 2147483647")
    check(run_values.types["c:@Ea@DISPATCH_WALLTIME_NOW"] == "unsigned long long", "the run gives the enum's type unsigned long long")
    check(run_values.unparsed["Broken"] == "Broken.h:1:1: error: fixture", "the run names the module it does not parse, with its error")

    local ir = {
        row({"Metal", "enum", "c:@E@MTLStages", "-", "MTLStages", "-", "MTLCommandEncoder.h", "1", "-", "-", "NSUInteger"}),
        row({"Metal", "enumconst", "c:@E@MTLStages@MTLStageAll", "MTLStages", "MTLStageAll", "-", "MTLCommandEncoder.h", "75",
             "-", "-", "-", "-", "-", "9223372036854775807"}),
        row({"Dispatch", "enum", "c:@Ea@DISPATCH_WALLTIME_NOW", "-", "-", "-", "time.h", "1", "-", "-", "unsigned long"}),
        row({"Dispatch", "enumconst", "c:@Ea@DISPATCH_WALLTIME_NOW@DISPATCH_WALLTIME_NOW", "-", "DISPATCH_WALLTIME_NOW", "-", "time.h",
             "2", "-", "-", "-", "-", "-", "18446744073709551614"}),
        row({"DispatchIntrospection", "enumconst", "c:@Ea@DISPATCH_WALLTIME_NOW@DISPATCH_WALLTIME_NOW", "-", "DISPATCH_WALLTIME_NOW",
             "-", "introspection.h", "2", "-", "-", "-", "-", "-", "18446744073709551614"}),
        row({"Foundation", "enumconst", "c:@Ea@NSDateComponentUndefined@NSDateComponentUndefined", "-", "NSDateComponentUndefined", "-",
             "NSCalendar.h", "418", "-", "-", "-", "-", "-", "9223372036854775807"}),
        row({"Foundation", "enumconst", "c:@E@Foundation@NotDeclared", "Foundation", "NotDeclared", "-", "Foundation.h", "3",
             "-", "-", "-", "-", "-", "42"}),
        row({"Broken", "enumconst", "c:@E@Broken@BrokenValue", "Broken", "BrokenValue", "-", "Broken.h", "3",
             "-", "-", "-", "-", "-", "7"}),
    }
    local changed, absent, unparsed, types = port.apply(ir, run_values)
    local function value_of(index) return ir[index][14] end
    check(changed == 2, "two enumerators take the run's value (got " .. changed .. ")")
    check(value_of(2) == "2147483647", "MTLStageAll is 2147483647 on the port's triple (got " .. value_of(2) .. ")")
    check(value_of(6) == "2147483647", "NSDateComponentUndefined is 2147483647 on the port's triple (got " .. value_of(6) .. ")")
    check(value_of(4) == "18446744073709551614" and value_of(5) == "18446744073709551614",
          "DISPATCH_WALLTIME_NOW keeps its value, which the run gives unchanged")
    check(types == 1 and ir[3][11] == "unsigned long long", "the enum's type takes the run's unsigned long long (got " .. ir[3][11] .. ")")
    check(ir[1][11] == "NSUInteger", "an enum the run gives the same type keeps it")
    check(absent == 2 and unparsed == 1, "two enumerators have no value in the run, one of them in the module that does not parse (got "
          .. absent .. ", " .. unparsed .. ")")
    check(value_of(7) == "42" and value_of(8) == "7", "an enumerator the run does not give keeps the IR's value")

    write(file, "enumconst\tA\tc:@E@X@Y\t1\nenumconst\tB\tc:@E@X@Y\t2\n")
    local refused = false
    try {
        function () port.read(file) end,
        catch {
            function () refused = true end
        }
    }
    check(refused, "a USR with two values in the run is refused")

    os.rm(root)
    print("port enums test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function main()
    run()
end
