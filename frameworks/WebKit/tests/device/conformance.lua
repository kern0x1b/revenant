local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/conformance.lua [--suite DIR] TEST...
  runs named tests of the Khronos WebGL conformance suite in Safari on the phone, e.g.
  conformance/rendering/culling.html. DIR is the suite's sdk/tests folder, else WEBGL_TESTS;
  HOST_IP names the address the phone reaches this Mac on and TEST_PORT the port, 8905 by default.]]

function main(...)
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    local tree = import("tree", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "lib"), anonymous = true})
    local given, names = tree.arguments({...}, {suite = "value", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local suite = given.suite or os.getenv("WEBGL_TESTS")
    if not suite or not os.isdir(path.join(suite, "conformance")) then
        raise("no conformance suite at %s: name its sdk/tests folder with --suite or WEBGL_TESTS", tostring(suite))
    end
    if #names == 0 then
        raise("name at least one test, e.g. conformance/rendering/culling.html")
    end
    suite = path.absolute(suite)
    local host = os.getenv("HOST_IP") or harness.host_address()
    local port = harness.port(8905)
    local runner = path.join(suite, "conformance-runner.html")
    os.cp(path.join(harness.folder(), "conformance-runner.html"), runner)
    local phone = harness.phone()
    local ok, errors = true, nil
    try {
        function ()
            harness.with_server(port, {folder = suite}, function (server)
                os.sleep(1000)
                phone:restart_safari(5)
                phone:open_url(string.format("http://%s:%d/conformance-runner.html?tests=%s&run=%d", host, port,
                                             table.concat(names, ","), harness.run_token()))
                server:wait_for("RUNNER%%20DONE", 90, 5)
                for _, report in ipairs(server:reports()) do
                    print(report)
                end
            end)
        end,
        catch {
            function (raised)
                ok, errors = false, raised
            end
        }
    }
    os.tryrm(runner)
    if not ok then
        raise(errors)
    end
end
