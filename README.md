![alt tag](img/types.png)

This was originally created as a small side project to pass some time, and although it's grown past that by now, it's nowhere near perfect. If you find any bugs that look fixable, please tell me; the hardest part about solving problems is not how to fix the issue, but how to find it.
# Syntax #
### Comments ###
Single-line comments are done with a pair of '#':

    ## some comment
Block comments are done like this:

    [#
	    some text
	#]

### Variable assignment: ###
    $var_name = value;
All variables are stored with global visibility except function and type arguments, so be careful when choosing names.
### Boolean Logic ###

    $var1 == $var2
    $var1 <= $var2
    $var1 ~= $var2

All boolean operators are the same as those in Lua.
### If/Select Statements ###
`NOT IMPLEMENTED YET`
### Loops ###
For loops:

    ## Default-step for loop:
    for ($varname = $start, $end) {
        print($varname);
        ## other stuff
    };
    ## Set-step for loop:
    ## NOT IMPLEMENTED YET
    ## Dynamic-step for loop
    ## NOT IMPLEMENTED YET
While loops:

    ## NOT IMPLEMENTED
The loop will repeat until $some_conditions is false. The conditions are re-evaluated after each loop.
### Function definition ###

    function funcName($arg1, $arg2)
    {
	    ## do stuff
	    return $arg1;
    };
NOTE: RETURN STATEMENTS ARE NOT IMPLEMENTED YET
### Types ###
`NOT IMPLEMENTED YET`
### Arrays ###
`NOT IMPLEMENTED YET`
### Output ###
To print things, you can use either this:

    print("stuff");
or this:

    print "stuff"; ## NOT IMPLEMENTED YET
Those methods are equivalent, although the second is more prone to bugs.
### File I/O ###
`NOT IMPLEMENTED YET`
### Frames ###
You can modify the behavior of the language itself with frames - Lua code that defines new operators and syntax defititions. To load a frame, use

    loadframe "filename.fr"; ## NOT IMPLEMENTED YET
On load, the code inside *filename.fr* will be run as raw Lua code - this feature can technically be used to run code as well as create frames, and doing so is not discouraged.
### Language Extensions ###
`NOT IMPLEMENTED YET`
### Important Interpreter/Compiler Notes ###
## Interpreter ##
- Although it functions exactly the same as executing pre-compiled program data, it is roughly 50% slower. Once debug capabilities are added, it will be possible to debug NGN code or AST maps, but not compiled program data.
## Compiler ##
- Rule components enclosed in curly braces will be compiled rather than being kept as literal strings - keep this in mind when creating new rules.
