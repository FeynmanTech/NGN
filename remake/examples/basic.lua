local t, r = ngn.tokenize([[
$a = 1;
$b = 2;
for ($n = 1, 10) {
    print($n)
    $a += $n;
    $b += $a;
};
print($a, $b)
]])
print(t)
ngn.run(t)
