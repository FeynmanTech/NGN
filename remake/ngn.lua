LOG = ""

function trim(s)
    return (tostring(s):gsub("^%s*(.-)%s*$", "%1"))
end

ngn = {}

ngn.vars = {}
ngn.rules = {}
ngn.exec = {}

ngn.rules["var"] = "STR ;$  #;STR*;=  #;ETC*;SEM#;"
ngn.exec["var"] = function(lvars, var, etc)
    ngn.vars[var] = ngn.eval(etc, lvars)
end
---[[
ngn.rules["$"] = "$  #;STR*;= v#;ETC*;SEM#;"
ngn.exec["$"] = function(lvars, var, etc)
    ngn.vars[var] = ngn.eval(etc, lvars)
end
--]]

ngn.rules["pvar"] = "STR ;$  #;STR*;SEM ;"
ngn.exec["pvar"] = function(lvars, var)
    print(type(ngn.vars[var]) .. ": " .. tostring(ngn.vars[var]))
end

ngn.rules["plvar"] = "STR ;$  #;STR*;SEM ;"
ngn.exec["plvar"] = function(lvars, var)
    print(type(lvars[var]) .. ": " .. tostring(lvars[var]))
end

ngn.rules["for"] = "STR ;(  #;$  #;STR*;=  #;ETC*;,  #;ETC*;){{#;ETC*;}}} ;"
ngn.exec["for"] = function(lvars, var, start, stop, code)
    --print("for")
    code = trim(code):sub(2,-1)
    for n = ngn.eval(start, lvars), ngn.eval(stop, lvars) do
        lvars[var] = n
        ngn.lex(code, lvars)
    end
end

ngn.level = 0
ngn.openers = [[{([<]] .. '"' .. "'"
ngn.closers = [[})]>]] .. '"' .. "'"
ngn.container = 0

ngn.token_keys = {
["STR"] = function(c, n) return c:find("%a") end,
["ETC"] = function(c, n) 
    if not n then 
        return true 
    else 
        if ngn.level <= 1 then
            if ngn.token_keys[n:sub(1,-2)] then
                return not(ngn.token_keys[n:sub(1,-2)](c))
            elseif not(n:sub(1,3):find(c, 1, true)) then
                if ngn.openers:find(c) then
                    ngn.level = ngn.level + 1
                    ngn.container = ngn.openers:find(c)
                end
                return true
            else
                return false
            end
        else
            if (ngn.closers:find(c) or -1) == ngn.container then
                ngn.level = ngn.level - 1
                ngn.container = 0
            end
            return true
        end
    end
end,
["SEM"] = function(c, n) return c == ";" end,
}
function ngn.tokenize(rule, str, p)
    local s = ngn.rules[rule]
    local rt = {}
    local ct = 1
    local arg = {}
    for r in s:gmatch("(....);") do
        table.insert(rt, r)
    end
    local cs = ""
    while ct < #rt and p <= #str do
        local cc = str:sub(p,p)
        if (ngn.token_keys[rt[ct]:sub(1,-2)] and ngn.token_keys[rt[ct]:sub(1,-2)](cc, rt[ct+1])) or (rt[ct]:sub(-1,-1) == "#" and rt[ct]:sub(1,-2):find(cc, 1, true)) then
            --LOG = LOG .. cc .. " - " .. rt[ct] .. " - PASS" .. "\n"
            cs = cs .. cc
            p = p + 1
        else
            --LOG = LOG .. cc .. " - " .. rt[ct] .. " - FAIL" .. " - KEYRES: " .. tostring(not(not(ngn.token_keys[rt[ct]:sub(1,-2)]))) .. ", " .. tostring(ngn.token_keys[rt[ct]:sub(1,-2)] and ngn.token_keys[rt[ct]:sub(1,-2)](cc, rt[ct+1])) .. "\n"
            if rt[ct]:sub(4,4) == "*" then table.insert(arg, cs) end
            cs = ""
            ct = ct + 1
        end
    end
    --print(table.concat(arg, ", "))
    return p, {rule, arg}
end

function ngn.lex(str, lvars)
    str = str:gsub("\n", " ")
    --print(str)
    local lvars = lvars or {}
    local out = {}
    local n = 1
    local cr = ""
    while n < #str do
        local cs = str:sub(n,n)
        cr = cr .. trim(cs)
        if ngn.rules[cr] then
            local np, ex = ngn.tokenize(cr, str, n)
            n = np+1
            table.insert(out, ex)
            cr = ""
        else
            n = n + 1
        end
    end
    ngn.run(out, lvars)
    return out
end

ngn.run = function(x, lvars)
    for i, v in ipairs(x) do
        ngn.exec[v[1]](lvars, unpack(v[2]))
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
