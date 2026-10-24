local driver = import("driver", {rootdir = os.scriptdir(), anonymous = true})

local CASE = "photos_assets"

local function expect(name, condition)
    if not condition then
        raise("%s", name)
    end
end

function main()
    local passing = table.concat({
        "REVENANT-CASE photos_assets positive pass ",
        "REVENANT-CASE photos_assets negative fail the check failed",
        "REVENANT-DONE cases=1",
        ""}, "\n")
    local cases, finished = driver.parse(passing)
    expect("a run with its done marker and both modes as expected has no failures",
           #driver.judge(CASE, cases, finished, "") == 0)

    local crashed = "check ok the photo library grants access\n"
    cases, finished = driver.parse(crashed)
    local found = driver.judge(CASE, cases, finished, "exit status 0 signal=11")
    expect("a crashing guest program fails even after a passing check", #found == 1)
    expect("the failure names the missing done marker", found[1]:find("did not finish", 1, true) ~= nil)
    expect("the failure carries the crash reason", found[1]:find("signal=11", 1, true) ~= nil)

    local negativePasses = table.concat({
        "REVENANT-CASE photos_assets positive pass ",
        "REVENANT-CASE photos_assets negative pass ",
        "REVENANT-DONE cases=1",
        ""}, "\n")
    cases, finished = driver.parse(negativePasses)
    expect("a negative control that passes is a failure", #driver.judge(CASE, cases, finished, "") == 1)

    local values, failure = driver.guarded(function ()
        raise("the app raised %s", "inside the run")
    end)
    expect("a body that raises yields no values", values == nil)
    expect("the raise message is kept", failure ~= nil and failure:find("inside the run", 1, true) ~= nil)

    values = driver.guarded(function ()
        return "cases", true, ""
    end)
    expect("a body that returns yields its values", values ~= nil and values[1] == "cases" and values[2] == true)
end
