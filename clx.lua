--# Main
-- CL Parser

cl = {}

cl.GLOBAL_POS = 0
cl.PRIMARY_POS = 0
cl.GLOBAL_SRC = ""

-- Basic demos
src = {}
src.factorial = [[
    function factorial : num, cval {
        if $cval ~= 0 {
            if $num <= 1 {
                return $cval;
            } else {
                return factorial($num - 1, $cval * $num);
            };
        } else {
            return factorial($num - 1, $num);
        };
    };
    print(factorial(10,0));
]]

src.errors = [[
$nd += 1;
    
$nd = 1;
$nd += "test";
    
$str = "string";
$str++;
]]

--# StrOps
function cl.getArgsFromString(argStr, lvars)
    local args = {}
    local aPos, aCount, aCurrent, aLevel, aLChar = 1, 1, "", 0, ""
    local aChars = {["("] = ")", ["{"] = "}", ['"'] = '"', ["'"] = "'", ["["] = "]"}
    local aStr = ""
    local aIndex
    --print(argStr)
    while aPos <= #argStr do
        local cc = argStr:sub(aPos, aPos)
        aStr = aStr .. cc .. ": level " .. aLevel .. ", end " .. aLChar .. "\n"
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
                args[cl.eval(aIndex, lvars)] = cl.eval(aCurrent, lvars)
            else
                table.insert(args, cl.eval(aCurrent, lvars))
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
            aPos = aPos + 1
            --]=]
        else
            aCurrent = aCurrent .. cc
        end
        --print(cc)
        aPos = aPos + 1     
    end
    return args
end

--# Parse
function trim(s)
    return (tostring(s):gsub("^%s*(.-)%s*$", "%1"))
end

cl.key, cl.proc, cl.rank = {}, {}, {}

cl.vars = {}

cl.types = {}

cl.objects = {}

cl.handles = {}

cl.CurrentLine = 1
cl.CurrentChar = 1

-- for $varname : start, end, step { statement; }; 
cl.key["for"] = "for%s-%$(%S+)%s-:%s-([^,]-),%s-([^,{]-),%s-([^{]-)%s-(%b{});"
cl.proc["for"] = function(lvars, var, start, stop, step, src)
    lvars[var] = tonumber(cl.eval(start, lvars))
    local _stop, _step = stop, step
    stop = tonumber(cl.eval(stop, lvars))
    if not stop then
        clError("Non-numeric limit: " .. _stop)
    end
    step = tonumber(cl.eval(step, lvars))
    if not step then
        clError("Non-numeric step: " .. _step)
    end
    while lvars[var] <= stop do
        cl.parse(src:sub(2, -2), lvars, true)
        lvars[var] = lvars[var] + step
    end
end
cl.rank["for"] = 0

cl.key["for-default"] = "for%s-%$(%S+)%s-:%s-([^,]-),%s-([^,{]-)%s-(%b{});"
cl.proc["for-default"] = function(lvars, var, start, stop, src)
    lvars[var] = tonumber(cl.eval(start, lvars))
    local _stop = stop
    stop = tonumber(cl.eval(stop, lvars))
    if not stop then
        clError("Non-numeric limit: " .. _stop)
    end
    while lvars[var] <= stop do
        cl.parse(src:sub(2, -2), lvars, true)
        lvars[var] = lvars[var] + 1
    end
end
cl.rank["for-default"] = 0

-- for $var : start, stop [ statement; ] { statement; };
cl.key["for-dynamic"] = "for%s-%$(%S+)%s-:%s-([^,]-),%s-([^%[]-)%s-(%b%[%])%s-(%b{});"
cl.proc["for-dynamic"] = function(lvars, var, start, stop, step, src)
    lvars[var] = tonumber(cl.eval(start, lvars))
    local _stop, _step = stop, step
    stop = tonumber(cl.eval(stop, lvars))
    if not stop then
        clError("Non-numeric limit: " .. _stop)
    end
    step = tonumber(cl.eval(step, lvars))
    if not step then
        clError("Non-numeric step: " .. _step)
    end
    while lvars[var] <= stop do
        cl.parse(src:sub(2, -2), lvars, true)
        cl.parse(step, lvars, true)
    end
end
cl.rank["for-dynamic"] = 0

cl.key["for-iterator"] = "for%s+%$(%w+)%s-in%s-(.-)%s-(%b{});"
cl.proc["for-iterator"] = function(lvars, var, i, src)
    local v = cl.eval(i, lvars)
    if type(v) == "table" then
        for _, v in pairs(v) do
            lvars[var] = v
            cl.parse(src, lvars, true)
        end
    elseif type(v) == "string" then
        for c = 1, #v do
            lvars[var] = v:sub(c,c)
            cl.parse(src, lvars, true)
        end
    else
        clError("Invalid value for iterator")
    end
end
cl.rank["for-iterator"] = 1

-- while conditions { statement; };
cl.key["while"] = "while%s-([^{]-)%s-(%b{});"
cl.proc["while"] = function(lvars, conditions, src)
    --lvars[var] = start
    while cl.isTrue(conditions, lvars) do
        cl.parse(src:sub(2, -2), lvars, true)
    end
end
cl.rank["while"] = 0

-- if conditions { statement; };
cl.key["if"] = "if%s-([^{]-)%s-(%b{});"
cl.proc["if"] = function(lvars, conditions, src)
    --lvars[var] = start
    if cl.isTrue(conditions, lvars) then
        cl.parse(src:sub(2, -2), lvars, true)
    end
end
cl.rank["if"] = 0

cl.key["if.-{.-}%s-else%s-%b{}"] = "if%s-([^{]-)%s-(%b{})%s-else%s-(%b{});"
cl.proc["if.-{.-}%s-else%s-%b{}"] = function(lvars, conditions, src, src2)
    --lvars[var] = start
    if cl.isTrue(conditions, lvars) then
        cl.parse(src:sub(2, -2), lvars, true)
    else
        cl.parse(src2:sub(2, -2), lvars, true)
    end
end
cl.rank["if.-{.-}%s-else%s-%b{}"] = 1

cl.key["if.-{.-}%s-elseif"] = "if%s-([^{]-)%s-(%b{})%s-(elseif%s-[^}]+%s-%b{}.-;~)"
cl.proc["if.-{.-}%s-elseif"] = function(lvars, conditions, src, chunk2)
    --lvars[var] = start
    if cl.isTrue(conditions, lvars) then
        cl.parse(src:sub(2, -2), lvars, true)
    else
        cl.parse(chunk2:sub(5, -1), lvars, true)
    end
end
cl.rank["if.-{.-}%s-elseif"] = 2

cl.key["return"] = "return(.-);"
cl.proc["return"] = function(lvars, args)
    --print("Returning...")
    args = trim(args)
    --[[
    _RETURN = ""
    for arg in args:gmatch("([^,]-),") do
        _RETURN = eval(arg, lvars)
    end
    --]]
    _RETURN = cl.eval(args, lvars)
    --print(_RETURN)
end
cl.rank["return"] = 0

cl.key["print"] = "print%s+(.-);"
cl.proc["print"] = function(lvars, stuff)
    print(unpack(cl.getArgsFromString(stuff, lvars)))
end
cl.rank["print"] = 2

cl.key["write"] = "write%s+(.-);"
cl.proc["write"] = function(lvars, stuff)
    local t = cl.getArgsFromString(stuff, lvars)
    for i, v in ipairs(t) do
        io.write(v)
    end
end
cl.rank["write"] = 2

cl.key["open"] = "open%s-(%b<>)%s-:%s-(%w+)%s-;"
cl.proc["open"] = function(lvars, file, var)
    cl.handles[var] = io.open(cl.eval(file:sub(2, -2), lvars), "r+")
end
cl.rank["open"] = 2

cl.key["file-read"] = "(%w+)%s-->%s-%$?(%w+)%s-;"
cl.proc["file-read"] = function(lvars, handle, var)
    if cl.handles[handle] then
        cl.vars[var] = cl.handles[handle]:read("*a")
    else
        clError("Attempt to read contents of null file handle")
    end
end
cl.rank["file-read"] = 1

--[[
EXAMPLE TYPEDEF:
local name = {}
name.__src = {}
name.__run = {}
name.__src.method1 = {"$arg1, $arg2"}
name.__run.method1 = function(arg1, arg2) end
name.__args = "$parameter1=def_val"
name.__cl.vars = {}
    name.__cl.vars.parameter1 = "def_val"
cl.types[tn] = name
--]]
cl.key["type"] = "type%s+(%S-)%s-:%s-([^{]-)%s-(%b{});"
cl.proc["type"]= function(lvars, name, vars, src)
    local t = {}
    t.__methods = {}
    t.__src = {}
    t.__vars = {}
    t.__args = vars
    t.__run = {}
    for v in (vars..","):gmatch("([^,]+)%s-,") do
        t.__vars[v:match("(%w+)%s-=%s-[^,+]") or v] = v:match("%w+%s-=%s-([^,-])")
    end
    for method, args, body in src:gmatch("@(%w+)%s-:%s-([^{]+)(%b{});") do
        t.__src[method] = {args, body:sub(2,-2)}
        t.__run[method] = function(self, arg) cl.parse(self.__src[method][2], arg, true) end
    end
    cl.types[name] = t
end
cl.rank.typedef = 2

cl.key["new"] = "new%s+([%w_]+)%s-(%b())%s-:%s-([%w_]+)%s-;"
cl.proc["new"] = function(lvars, t, args, name)
    if cl.types[t] then
        cl.objects[name] = cl.types[t]
        local arg = cl.getArgsFromString(args:sub(2,-2), lvars)
        local a = 1
        for av in cl.types[t].__args:gmatch("([%w_]+)") do
            arg[av] = arg[a]
            --print(av, arg[a])
            a = a + 1
        end
        for i, v in pairs(arg) do
            cl.objects[name].__vars[i] = v
        end
        cl.objects[name].__type = t
    else
        clError("Use of undeclared type " .. t)
    end
end

cl.key["load"] = "load%s+(.-);"
cl.proc["load"] = function(lvars, lib)
    local s, err = pcall(dofile, lib .. ".lib.lua")
    if not s then
        clError("Unable to load library")
    end
end

--@name>method(args);
--@[%w_]+%s-%>%s-[%w_]+%s-%b();
cl.key["%@%s-[%w_]+%s->%s-[%w_]+%s-%b()"] = "%@%s-([%w_]+)%s->%s-([%w_]+)%s-(%b())"
cl.proc["%@%s-[%w_]+%s->%s-[%w_]+%s-%b()"] = function(lvars, obj, method, args)
    if cl.objects[obj] and cl.objects[obj].__src[method] then
        local arg = cl.getArgsFromString(args:sub(2,-2), lvars)
        local a = 1
        for i, v in ipairs(arg) do
            arg[i] = cl.eval(v, lvars)
            --print(i, v)
        end
        for av in cl.objects[obj].__src[method][1]:gmatch("([%w_]+)") do
            arg[av] = cl.eval(arg[a], lvars)
            --print(av, arg[a])
            a = a + 1
        end
        for i, v in pairs(cl.objects[obj].__vars) do
            arg[i] = cl.eval(v, lvars)
        end
        cl.objects[obj].__run[method](cl.objects[obj], arg)
    elseif cl.objects[obj] and not cl.objects[obj].__src[method] then
        clError("Attempt to call undefined method "..method.." of "..cl.objects[obj].__type.." "..obj)
    else
        clError("Attempt to call method "..method.." of null object")
    end
end
cl.rank["%@%s-[%w_]+%s->%s-[%w_]+%s-%b()"] = 2

cl.key["loadframe"] = "loadframe%s-(%b\"\")%s-;"
cl.proc["loadframe"] = function(lvars, filename)
    --local gp = cl.GLOBAL_POS
    --local pp = cl.PRIMARY_POS
    local f = io.open(filename:sub(2, -2))
    local success = cl.loadframe(f and f:read("*all") or nil)
    --cl.GLOBAL_POS = gp
    --cl.PRIMARY_POS = pp
    if not success then
        clError("Unable to open file for parsing")
    end
    return success
end
cl.rank["loadframe"] = 1

function runMethod(str, lvars)
    _RETURN = nil
    cl.parse(str, lvars, true)
    return _RETURN
end

cl.ops, cl.opProc = {}, {}

cl.ops["="] = "$([%w_]+)%s-=%s-([^{][^;]+);"
cl.opProc["="] = function(lvars, var, val)
    cl.vars[var] = cl.eval(val, lvars)
    --print(var, cl.vars[var])
end

cl.ops["ArrayAssignment"] = "%$([%w_]+)%s-(%b[])%s-=%s-([^;]+);"
cl.opProc["ArrayAssignment"] = function(lvars, var, index, val)
    --print(var, cl.eval(index:sub(2, -2), lvars), cl.eval(val, lvars))
    cl.vars[var][cl.eval(index:sub(2, -2), lvars)] = cl.eval(val, lvars)
end

cl.ops["array"] = "%$(%w+)%s-=%s-(%b%{%});"
cl.opProc["array"] = function(lvars, var, val)
    cl.vars[var] = cl.getArgsFromString(val:sub(2, -2), lvars)
end

cl.ops["+="] = "$([%w_]+)%s-%+%s-=%s-([^;]+);"
cl.opProc["+="] = function(lvars, var, val)
    if not cl.vars[var] then
        clError("Operation on undefined variable $"..var)
        return
    elseif not tonumber(cl.vars[var]) then
        clError("Operation on non-numeric variable $"..var)
        return
    end
    local res = cl.eval(val, lvars)
    if not(tonumber(res)) then
        clError("Operation on numeric $" .. var .. " using non-numeric value")
        return
    end
    cl.vars[var] = cl.vars[var] + cl.eval(val, lvars)
end

cl.ops["++"] = "$([%w_]+)%s-%+%s-%+%s-;"
cl.opProc["++"] = function(lvars, var, val)
    if not cl.vars[var] then
        clError("Operation on undefined variable $"..var)
        return
    elseif not tonumber(cl.vars[var]) then
        clError("Numeric operation on variable $"..var .. " of non-numeric type " .. type(cl.vars[var]))
        return
    end
    cl.vars[var] = cl.vars[var] + 1
end

cl.ops["-="] = "$([%w_]+)%s-%-%s-=%s-([^;]+);"
cl.opProc["-="] = function(lvars, var, val)
    if not cl.vars[var] then
        clError("Operation on undefined variable $"..var)
        return
    elseif not tonumber(cl.vars[var]) then
        clError("Numeric operation on variable $"..var .. " of non-numeric type " .. type(cl.vars[var]))
        return
    end
    local res = cl.eval(val, lvars)
    if not(tonumber(res)) then
        clError("Operation on numeric $" .. var .. " using non-numeric value")
        return
    end
    cl.vars[var] = cl.vars[var] + cl.eval(val, lvars)
end

cl.ops["--"] = "$([%w_]+)%s-%-%s-%-%s-;"
cl.opProc["--"] = function(lvars, var, val)
    if not cl.vars[var] then
        clError("Operation on undefined variable $"..var)
        return
    elseif not tonumber(cl.vars[var]) then
        clError("Numeric operation on variable $"..var .. " of non-numeric type " .. type(cl.vars[var]))
        return
    end
    cl.vars[var] = cl.vars[var] - 1
end

cl.ops[".="] = "$([%w_]+)%s-%.%s-=%s-([^;]+);"
cl.opProc[".="] = function(lvars, var, val)
    if not cl.vars[var] then
        clError("Operation on undefined variable $"..var)
        return
    end
    cl.vars[var] = tostring(cl.vars[var]) .. tostring(cl.eval(val, lvars))
end

cl.func = {}
_RETURNSTACK ={}

cl.key["function"] = "function%s-(%w-)%s-:%s-(.-)(%b{});"
cl.proc["function"] = function(lvars, name, args, src)
    --print("Defining function " .. name)
    local s = "return function("
    args = trim(args:gsub("%s", "") .. ",")
    local a = {}
    for arg in args:gmatch("([^,]-),") do
        --s = s .. arg .. ","
        table.insert(a, arg)
    end
    s = s .. table.concat(a, ",") .. ")\nlocal lvars = {}\n"
    for i, v in ipairs(a) do
        s = s .. "lvars['" .. v .. "']=" .. v .. "\n"
    end
    s = s .. "cl.parse([[" .. src:sub(2, -2) .. "]], lvars, true)\n return _RETURN end"
    --print(s)
    local f, err = loadstring(s)
    if f then
        cl.func[name] = f()
        --print(name, cl.func[name])
    else
        print(err)
    end
end

cl.key["macro"] = "macro%s-:%s-(%b\'\')%s-(%b[])%s-(%b{})%s-;"
cl.proc["macro"] = function(lvars, pattern, args, code)
    local arg = {}
    for a in (args:sub(2, -2) .. ","):gmatch("(.-),") do
        table.insert(arg, trim(a))
    end
    cl.key[pattern] = pattern:sub(2, -2)
    cl.proc[pattern] = function(lvars, ...)
        for i, v in ipairs(arg) do
            lvars[v:sub(2, -1)] = ({...})[i]
        end
        cl.parse(code, lvars, true)
    end
    cl.rank[pattern] = 1
end
cl.rank["macro"] = 1

cl.func.print = function(lvars, ...) 
    local t = {}
    for i, v in ipairs{...} do
        table.insert(t, v)
    end
    print(unpack(t))
end

cl.func.write = function(lvars, ...) 
    local t = {}
    for i, v in ipairs{...} do
        io.write(v)
    end
end

cl.func.set = function(lvars, name, val)
    cl.vars[name] = val
end

for i, v in pairs(math) do
    cl.func[i] = function(lvars, ...) return v(...) end
end

cl.func.simplifyType = function(lvars, str)
    local value;
    local f, err = loadstring("return " .. str)
    local s, val = pcall(f)
    if not(err) then value = val else value = str end
    return value
end
cl.func.value = function(lvars, str)
    return lvars[str] or cl.vars[str] or str
end

function cl.func.runfile(lvars, filename, is_critical)
    local success = cl.parseFile(filename)
    if is_critical ~= false and not success then
        cl.ALL_ERR_CRITICAL = true
        clError("Unable to open file for parsing")
    end
    return success
end

function cl.func.require(lvars, filename)
    local gp = cl.GLOBAL_POS
    local pp = cl.PRIMARY_POS
    local success = cl.parseFile(filename)
    cl.GLOBAL_POS = gp
    cl.PRIMARY_POS = pp
    if not success then
        clError("Unable to open file for parsing")
    end
    return success
end

cl.func.ignoreErrors = function(lvars, state)
    cl.ALL_ERR_CRITICAL = not state
end

cl.func.lua = function(lvars, s) return loadstring(s:gsub("cl.vars", "({...})[1]"))(cl.vars) end

getFunc = function(n) 
    --print(n, cl.func[n])
    return cl.func[n] 
end

function cl.loadframe(src)
    if src then
        local f, err = loadstring(src)
        if f then
            f()
            return true
        else
            print(err)
            return false
        end
    else
        return false
    end
end

CL_LOC = ""

cl.ALL_ERR_CRITICAL = true
cl.ERR_LEN = 30
function clError(msg)
    local l, c, lastLine = 1, 0, 0
    for cc = 1, cl.PRIMARY_POS do
        if cl.GLOBAL_SRC:sub(cc, cc) == "\n" then
            l = l + 1
            lastLine = cc
        end
    end
    c = cl.PRIMARY_POS - lastLine
    local sc, ec = math.max(1, cl.PRIMARY_POS - cl.ERR_LEN), math.min(#cl.GLOBAL_SRC, cl.PRIMARY_POS + cl.ERR_LEN)
    local startEllipsis, endEllipsis = math.ceil(1/(cl.PRIMARY_POS-1)), 1
    for _sc = math.max(1, cl.PRIMARY_POS - cl.ERR_LEN), cl.PRIMARY_POS do
        if cl.GLOBAL_SRC:sub(_sc, _sc) == "\n" then
            sc = _sc
            startEllipsis = 0
        end
    end
    for _ec = math.min(#cl.GLOBAL_SRC, cl.PRIMARY_POS + cl.ERR_LEN), cl.PRIMARY_POS, -1 do
        if cl.GLOBAL_SRC:sub(_ec, _ec) == "\n" then
            ec = _ec
            endEllipsis = 0
        end
    end
    local context = (("..."):rep(startEllipsis)..cl.GLOBAL_SRC:sub(sc, ec)..("..."):rep(endEllipsis)):gsub("\n", "")
    print('Error: line ' .. l .. ":" .. c .. '\n' .. context .. "\n" .. msg .. "\n")
    if cl.ALL_ERR_CRITICAL then
        os.exit()
    end
end

function cl.eval(statement, lvars)
    cl.lvars = lvars
    statement = tostring(statement) .. " " -- easy bugfix
    lvars = lvars or {}
    local value
    for i, v in pairs(lvars) do
        statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "cl.lvars[ [[" .. i .. "]] ]%1")
        statement = statement:gsub("%$" .. tostring(i) .. "(%W)", "cl.lvars[ [[" .. i .. "]] ]%1")
    end
    for i, v in pairs(cl.vars) do
        statement = statement:gsub("%$" .. tostring(i) .. "%s-(%b[])", "cl.vars[ [[" .. tostring(i) .. "]] ]%1")
        statement = statement:gsub("%$" .. tostring(i) .. "(%W)", "cl.vars[ [[" .. i .. "]] ]%1")
    end
    statement = statement:gsub("(%@%s-[%w_]+%s->%s-[%w_]+%s-%b())", "runMethod[[%1]]")
    for i, v in pairs(cl.func) do
        statement = string.gsub(statement, i.."%s-(%b())", "(getFunc([["..i.."]]))(cl.lvars, unpack(cl.getArgsFromString('%1', cl.lvars)))")
    end
    local f, err = loadstring("return " .. statement)
    local s, val = pcall(f)
    if not(err) then value = val else value = statement end
    return value
end

function cl.isTrue(statement, lvars)
    return cl.eval(statement, lvars)
end
    
function cl.parse(str, lvars, isSubParse)
    str = str .. "\n"
    lvars = lvars or {}
    while str:match("  ") do
        str = str:gsub("  ", " ")
    end
    str = str:gsub("%[#.-#%]", "")
    str = str:gsub("##.-\n", "")
    local pos = 1
    local p = true
    while (pos < #str) and p do
        if str:sub(pos, pos) == "\n" then
            cl.CurrentLine = cl.CurrentLine + 1
            cl.CurrentChar = 1
        else
            cl.CurrentChar = cl.CurrentChar + 1
        end
        local active = str:sub(pos, str:find("[^%w_]", pos) -1)
        if not isSubParse then
            cl.GLOBAL_POS = pos
            cl.PRIMARY_POS = pos
            cl.GLOBAL_SRC = str
        else
            cl.PRIMARY_POS = cl.GLOBAL_POS + pos
        end
        if str:sub(pos, pos):find("%s") then
            pos = pos + 1
        elseif str:sub(pos, pos) == "$" then
            for i, v in pairs(cl.ops) do
                if str:find(v, pos) == pos then
                    local opStr = trim(str:sub(pos, str:find(";", pos + 1)))
                    cl.opProc[i](lvars, opStr:match(cl.ops[i]))
                    pos = str:find(";", pos + 1) + 1
                end
            end
        elseif cl.key[active] and cl.proc[active] and str:find(cl.key[active], pos-1) == pos then
            local b, e = str:find(cl.key[active], pos-1)
            cl.proc[active](lvars or {}, str:match(cl.key[active], pos-1))
            pos = pos + e - b
        elseif cl.func[active] then
            local argStr = (str:match("%b()", pos):sub(2, -2) .. ","):gsub(",%s+", ",")
            local args = cl.getArgsFromString(argStr, lvars)
            cl.func[active](lvars, unpack(args))
            pos = str:find("%)%s-;", pos+1) + 1
        else
            local r, match = -1, ""
            for i, v in pairs(cl.key) do
                local b, e = str:find(v, pos-1)
                if (b == pos) and e then
                    if (cl.rank[i] or 0) > r then
                        r = cl.rank[i]
                        match = i
                    end
                end
            end
            if r == -1 then
                -- clError("Unexpected symbol " .. active)
                pos = pos + 1
            else
                --print("match")
                local b, e = str:find(cl.key[match], pos-1)
                if cl.proc[match] then cl.proc[match](lvars or {}, str:match(cl.key[match], pos-1)) end
                pos = pos + e - b
                match = true
            end
        end
    end
end

function cl.parseFile(f)
    local file = io.open(f, "r")
    if file then
        cl.parse(file:read("*all"))
        file:close()
        return true
    else
        return false
    end
end

if arg then
    if arg[1] then
        cl.parseFile(arg[1])
    end
end