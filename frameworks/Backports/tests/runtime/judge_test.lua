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

    cases, finished = driver.parse(passing)
    expect("a case inside the selection is judged by its results",
           #driver.judge(CASE, cases, finished, "", {"photos_assets", "scenekit_render"}) == 0)
    found = driver.judge("scenekit_render", cases, finished, "", {CASE})
    expect("a case outside the selection fails instead of passing on no results", #found == 1)
    expect("the failure names the selection variable", found[1]:find("REVENANT_RUNTIME_CASES", 1, true) ~= nil)
    expect("an empty selection means every case", #driver.judge(CASE, cases, finished, "", {}) == 0)

    local known = {"alias_public_name", "photos_assets", "scenekit_render"}
    local chosen = driver.parse_selection("scenekit_render, photos_assets,scenekit_render", known)
    expect("a selection is sorted without duplicates", #chosen == 2 and chosen[1] == "photos_assets" and chosen[2] == "scenekit_render")
    expect("no text selects nothing in particular", #driver.parse_selection(nil, known) == 0 and #driver.parse_selection("", known) == 0)
    local unknown = driver.guarded(function ()
        return driver.parse_selection("photos_assets,no_such_case", known)
    end)
    expect("a name that is not a case is refused", unknown == nil)

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
