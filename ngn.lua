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
    local aIndex
    while aPos <= #argStr do
        local cc = argStr:sub(aPos, aPos)
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
            aCurrent = ""
        else
            aCurrent = aCurrent .. cc
        end
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
{";", "<eol>"},
{"%.%.", "<concat>"},
{"([%d%.]+)", "<number:%1>"},
{"([%w_]+)", "<name:%1>"},
{"[%+%-%*/]", "%1"},
{"(%S+)", "<value:%1>"}
}

ngn.rules = {
{"<var:([^>]+)>%+=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] + ngn.evalToken(val, lvars) 
end},
{"<var:([^>]+)>%-=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] - ngn.evalToken(val, lvars) 
end},
{"<var:([^>]+)>%*=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] * ngn.evalToken(val, lvars) 
end},
{"<var:([^>]+)>/=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.vars[var] * ngn.evalToken(val, lvars) 
end},
{"<var:([^>]+)>=(.-)<eol>", function(lvars, var, val) 
    ngn.vars[var] = ngn.evalToken(val, lvars) 
end},
{"<for>(%b())(%b{})<eol>", function(lvars, step, code)
    local var, bounds
    for v, b in step:gmatch("<var:([%w_]+)>=(.+)%)") do var, bounds = v, b end
    bounds = ngn.args(bounds)
    start, stop = ngn.evalToken(bounds[1], lvars), ngn.evalToken(bounds[2], lvars)
    local code = code:gsub("@OBR;", "["):gsub("@CBR;", "]"):gsub("@OCB;", "{"):gsub("@CCB;", "}")
    for n = start, stop do
        lvars[var] = n
        if lvars.INTERP then ngn.interpret(code, lvars) else ngn.run(code, lvars) end
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

function ngn.testValidity(t, lvars)
    lvars = lvars or {}
    local foundMatch = false
    for r, a in t:gmatch("{(%b<>):(.-)};") do
        local arg = {}
        for ca in a:gmatch("%b[]") do
            table.insert(arg, ca:sub(2,-2))
        end
        if not ngn.rules[tonumber(r:sub(2,-2))] then return false end
        foundMatch = true
    end
    return foundMatch
end

function ngn.compile(t, lvars)
    local cs = ""
    lvars = lvars or {}
    while #t > 0 do
        for _, r in ipairs(ngn.rules) do
            local s, e = t:find(r[1])
            if s == 1 then
                local d = {t:match(r[1])}
                cs = cs .. "{<" .. _ .. ">:"
                for i, v in ipairs(d) do 
                    cs = cs .. "["
                    if v:match("%b{}") == v then
                        local comp = ngn.compile(v:sub(2,-2), lvars)
                        comp = comp
                            :gsub("%b[]",function(r)return "@OBR;"..r:sub(2,-2).."@CBR;" end)
                            :gsub("%b{}",function(r)return "@OCB;"..r:sub(2,-2).."@CCB;" end)
                        or comp
                        cs = cs .. comp
                    else
                        cs = cs .. v
                    end
                    cs = cs .. "];"
                end
                cs = cs .. "};"
                t = t:sub(e, -1)
                break break
            end
        end
        t = t:sub(2,-1)
    end
    return cs
end

function ngn.interpret(t, lvars)
    lvars = lvars or {}
    lvars.INTERP = true
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

function ngn.run(t, lvars)
    lvars = lvars or {}
    for b in t:gmatch("%b{};") do
        for r, a in b:gmatch("{(%b<>):(.-)};") do
            local arg = {}
            for ca in a:gmatch("(%b[]);") do
                table.insert(arg, ca:sub(2,-2))
            end
            ngn.rules[tonumber(r:sub(2,-2))][2](lvars, table.unpack(arg))
        end
    end
end

function ngn.eval(statement, lvars)
    ngn.lvars = lvars
    statement = tostring(statement) .. " " -- easy bugfix
    lvars = lvars or {}
    local value
    for i, v in pairs(lvars) do
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
        statement = statement:gsub("<var:" .. tostring(i) .. ">", "ngn.lvars['" .. i .. "']")
    end
    for i, v in pairs(ngn.vars) do
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
