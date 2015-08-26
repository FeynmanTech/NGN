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
ngn.func = {
["print_verbose"] = function(lvars, ...)
    for i, v in ipairs{...} do
        print(type(ngn.evalToken(v, lvars)) .. ": " .. tostring(ngn.evalToken(v, lvars)))
    end
end,
["print"] = function(lvars, ...)
    local t = {}
    for i, v in ipairs{...} do
        table.insert(t, tostring(ngn.eval(v, lvars)))
    end
    print(table.concat(t, "\t"))
end,
}

ngn.level = 0
ngn.openers = [[{([<]] .. '"' .. "'"
ngn.closers = [[})]>]] .. '"' .. "'"
ngn.container = 0

ngn.tokens = {
{"elseif", "<elseif>"},
{"else", "<else>"},
{"if", "<if>"},
{"for", "<for>"},
{"function", "<function>"},
{"%$([%w_%-]+)", "<var:%1>"},
{"%(", "("},
{"%)", ")"},
{"{", "{"},
{"}", "}"},
{"%[", "["},
{"%]", "]"},
{",", ","},
{'(%b"")', "<string:%1>"},
{"==", "=="},
{"=", "="},
--{"([%w_%-]+)%s-(%b())", "<functioncall:%1,%2>"},
{";", "<eol>"},
{"%.%.", "<concat>"},
{"([%d%.]+)", "<number:%1>"},
{"([%w_]+)", "<name:%1>"},
{"[%+%-%*/]", "%1"},
{"(%S+)", "<value:%1>"}
}

ngn.rules = {
{"<var:([^>]+)>=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.evalToken(val, lvars) 
end},
{"<add:(.-),(.-)>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] + ngn.eval(val, lvars)
end},
{"<subtract:(.-),(.-)>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] - ngn.eval(val, lvars) 
end},
{"<multiply:(.-),(.-)>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] * ngn.eval(val, lvars) 
end},
{"<divide:(.-),(.-)>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] / ngn.eval(val, lvars) 
end},
{"<increment:(.-)>", function(lvars, var) 
    ngn.vars[var] = ngn.vars[var] + 1
end},
{"<decrement:(.-)>", function(lvars, var) 
    ngn.vars[var] = ngn.vars[var] - 1
end},
{"<for>(%b())(%b{})<eol>", function(lvars, step, code)
    local var, bounds
    for v, b in step:gmatch("<var:([%w_]+)>=(.+)%)") do var, bounds = v, b end
    --print(bounds)
    bounds = ngn.args(bounds)
    start, stop = ngn.evalToken(bounds[1], lvars), ngn.evalToken(bounds[2], lvars)
    --print(start, stop)
    for n = start, stop do
        lvars[var] = n
        ngn.run(code:sub(2,-2), lvars)
    end
end},
{"<name:([%w_]+)>(%b())", function(lvars, func, args) 
    local o = {}
    args = args:sub(2,-2)
    for i, v in ipairs(ngn.args(args, lvars)) do table.insert(o, ngn.evalToken(v, lvars)) end
    ngn.func[func](lvars, unpack(o))
end},
{"<function><name:(.*)>(%b())(%b{})<eol>", function(lvars, name, a, c)
    local args = {}
    for i, v in ipairs(ngn.args(a:sub(2,-2), lvars)) do
        table.insert(args, v:match("<var:(.*)>"))
    end
    ngn.func[name] = function(lvars, ...)
        for i, v in ipairs{...} do
            if args[i] then
                lvars[args[i]] = ngn.evalToken(v, lvars)
            end
        end
        ngn.run(c:sub(2,-2), lvars)
    end
end},
}

function ngn.tokenize(str)
    str = str:gsub("%[#.-#%]", ""):gsub("##.-\n", "")
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
        statement = statement:gsub("%$" .. tostring(i) .. "([^%w_%-])", "ngn.lvars['" .. i .. "']%1")
    end
    for i, v in pairs(ngn.vars) do
        statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "ngn.vars[ [[" .. tostring(i) .. "]] ]%1")
        statement = statement:gsub("%$" .. tostring(i) .. "([^%w_%-])", "ngn.vars[ [[" .. i .. "]] ]%1")
    end
    for i, v in pairs(ngn.func) do
        statement = string.gsub(statement, i.."%s-(%b())", "(ngn.func['"..i.."'])(ngn.lvars, unpack(ngn.getArgsFromString('%1', ngn.lvars)))")
    end
    local f, err = loadstring("return " .. statement)
    local s, val = pcall(f)
    if not(err) then value = val else value = statement end
    return value
end

function ngn.evalToken(statement, lvars)
    ngn.lvars = lvars
    statement = tostring(statement) .. " " -- easy bugfix
    lvars = lvars or {}
    local value
    for i, v in pairs(lvars) do
        --print(i, v)
        --statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "ngn.lvars[ [[" .. i .. "]] ]%1")
        statement = statement:gsub("<var:" .. tostring(i) .. ">", "ngn.lvars['" .. i .. "']")
    end
    for i, v in pairs(ngn.vars) do
        --statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "ngn.vars[ [[" .. tostring(i) .. "]] ]%1")
        statement = statement:gsub("<var:" .. tostring(i) .. ">", "ngn.vars[ [[" .. i .. "]] ]")
    end
    for i, v in pairs(ngn.func) do
        statement = string.gsub(statement, i.."%s-(%b())", "(ngn.func['"..i.."'])(ngn.lvars, unpack(ngn.getArgsFromString('%1', ngn.lvars)))")
    end
    statement = statement:gsub("<number:([%d%.]+)>", "%1")
    statement = statement:gsub("<concat>", "..")
    statement = statement:gsub("<string:(.-)>", "%1")
    local f, err = loadstring("return " .. statement)
    local s, val = pcall(f)
    if not(err) then value = val else value = statement end
    return value
end
