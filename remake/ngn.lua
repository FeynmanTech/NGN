LOG = ""

function trim(s)
    return (tostring(s):gsub("^%s*(.-)%s*$", "%1"))
end

quotepattern = '(['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..'])'
esc = function(str)
    return str:gsub(quotepattern, "%%%1")
end

ngn = {}

function ngn.args(argStr, lvars)
    local args = {}
    local aPos, aCount, aCurrent, aLevel, aLChar = 1, 1, "", 0, ""
    local aChars = {["("] = ")", ["{"] = "}", ['"'] = '"', ["'"] = "'", ["["] = "]"}
    --local aStr = ""
    local aIndex
    --print(argStr)
    while aPos <= #argStr do
        local cc = argStr:sub(aPos, aPos)
        --aStr = aStr .. cc .. ": level " .. aLevel .. ", end " .. aLChar .. "\n"
        if aChars[cc] then
            aLevel = aLevel + 1
            aLChar = aChars[cc]
            if cc == "[" and aLevel == 0 then
                aIndex = argStr:match("%b[]", aPos):sub(2, -2)
                aCurrent = aCurrent + argStr:match("%b[]", aPos):sub(2, -2):len()
            else
                aCurrent = aCurrent .. cc
            end
        elseif cc == aLChar then
            aLevel = aLevel - 1
            aCurrent = aCurrent .. cc
            aLChar = ""
        elseif (cc == "," and aLevel == 0) or aPos >= #argStr then
            if aPos >= #argStr and cc ~= "," then
                aCurrent = aCurrent .. cc
            end
            if aIndex then
                args[ngn.eval(aIndex, lvars)] = ngn.eval(aCurrent, lvars)
            else
                table.insert(args, ngn.eval(aCurrent, lvars))
            end
            aIndex = nil
            --print("Arg: ", aCurrent)
            aCurrent = ""
            --[[
            while aPos <= #argStr and argStr:sub(aPos, aPos):match("%s") do
                aPos = aPos + 1
            end
            --[=[
            --]]
            aPos = aPos + 0
            --]=]
        else
            aCurrent = aCurrent .. cc
        end
        --print(cc)
        aPos = aPos + 1     
    end
    return args
end

ngn.vars = {}

ngn.level = 0
ngn.openers = [[{([<]] .. '"' .. "'"
ngn.closers = [[})]>]] .. '"' .. "'"
ngn.container = 0

ngn.tokens = {
{"if", "<if>"},
{"for%s-(%b())%s-(%b{});", "<for:%1,%2>"},
{"for", "<for>"},
{"%$(%w+)%s+=%s+(.-);", "<assignment:%1,%2>"},
{"%$(%w+)%s-%+=%s-(.-);", "<add:%1,%2>"},
{"%$(%w+)%s-%-=%s-(.-);", "<subtract:%1,%2>"},
{"%$(%w+)%s-%*=%s-(.-);", "<multiply:%1,%2>"},
{"%$(%w+)%s-/=%s-(.-);", "<divide:%1,%2>"},
{"%$(%w+)%s-%+%+%s-;", "<increment:%1>"},
{"%$(%w+)%s-%-%-%s-;", "<decrement:%1>"},
{"%$(%w+)", "<var:%1>"},
{"%(", "("},
{"%)", ")"},
{"{", "{"},
{"}", "}"},
{"%[", "["},
{"%]", "]"},
{'(%b"")', "<string:%1>"},
{"==", "<equals>"},
{"=", "="},
{"(%w+)%s-(%b())", "<functioncall:%1,%2>"},
{";", "<eol>"},
{"(%S+)", "<value:%1>"}
}

ngn.rules = {
{"<assignment:(.-),(.-)>", function(lvars, var, val) 
    ngn.vars[var] = ngn.eval(val, lvars) 
    print('"' .. var .. ' = "' .. val .. '"')
end}
}

function ngn.tokenize(str)
    local t, r = "", ""
    while #str > 0 do
        for _, ct in ipairs(ngn.tokens) do
            local s, e = str:find(ct[1])
            if s == 1 then
                t = t .. str:sub(s, e):gsub(ct[1], ct[2])
                r = r .. ct[2]:gsub("%S?%%%d", "")
                str = str:sub(e, -1)
                break break
            end
        end
        str = str:sub(2,-1)
    end
    return t, r
end

function ngn.run(t, lvars)
    lvars = lvars or {}
    while #t > 0 do
        for _, r in ipairs(ngn.rules) do
            local s, e = t:find(r[1])
            if s == 1 then
                r[2](lvars, t:match(r[1]))
                t = t:sub(e, -1)
                break break
            end
        end
        t = t:sub(2,-1)
    end
end

function ngn.eval(statement, lvars)
    ngn.lvars = lvars
    statement = tostring(statement) .. " " -- easy bugfix
    lvars = lvars or {}
    local value
    for i, v in pairs(lvars) do
        --print(i, v)
        --statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "ngn.lvars[ [[" .. i .. "]] ]%1")
        statement = statement:gsub("%$" .. tostring(i) .. "(%W)", "ngn.lvars['" .. i .. "']%1")
    end
    for i, v in pairs(ngn.vars) do
        statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "ngn.vars[ [[" .. tostring(i) .. "]] ]%1")
        statement = statement:gsub("%$" .. tostring(i) .. "(%W)", "ngn.vars[ [[" .. i .. "]] ]%1")
    end
    local f, err = loadstring("return " .. statement)
    local s, val = pcall(f)
    if not(err) then value = val else value = statement end
    return value
end
