success, socket = pcall(require, "socket")
--print("compiling")
local s = socket.gettime()
local t, r = ngn.tokenize([[
## Basic var ops
$a = 1;
$b = 2;
$str = "nums: ";
for ($n = 1, 500) {
$str = $str .. $n .. " ";
$a += $n;
$b += $a;
};

## Extended
print($str);
print_verbose($a, $b);
    
function multiply($var1, $var2)
{
print($var1 * $var2);
};
multiply(2, 3);
]])
local t1 = socket.gettime() - s
s = socket.gettime()
local ct = ngn.compile(t)
local t2 = socket.gettime() - s
s = socket.gettime()
print("Compiled:")
ngn.run(ct)
local t3 = socket.gettime() - s
print(("~"):rep(50).."\nInterpreted:")
s = socket.gettime()
ngn.interpret(t)
local t4 = socket.gettime() - s
print("Lexing: " .. t1 .. "\nCompiling: " .. t2 .. "\nRunning: " .. t3 .. "\n\nWhen interpreted: " .. t4)
