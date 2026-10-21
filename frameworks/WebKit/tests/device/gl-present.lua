local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/gl-present.lua [HOST]
  checks that a WebGL canvas the GPU drew reaches the screen: it loads a canvas cleared to red,
  prints how much of the page area is red, and fails when the answer is absent. The screenshot
  goes to `$HOME/.revenant/cache/<task>/webkit-shots/gl-present.png`.]]

function main(host)
    if host == "--help" then
        print(USAGE)
        return
    end
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    host = host or harness.host_address()
    local port = harness.port(8899)
    local phone = harness.phone()
    local shot = harness.with_server(port, {}, function ()
        os.sleep(1000)
        phone:restart_safari(6)
        phone:open_url(string.format("http://%s:%d/gl-present.html?run=%d", host, port, harness.run_token()))
        os.sleep(14000)
        return phone:screenshot("gl-present.png")
    end)
    local red = harness.painted(shot, "255,0,0")
    print("webgl canvas on screen: " .. red)
    if red == "absent" or red == "no shot" then
        raise("the canvas did not reach the screen")
    end
end
