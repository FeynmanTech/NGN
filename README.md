![alt tag](img/types.png)

I wrote this in about a day because I was too tired and stressed to do actual work, so don't be surprised if it's extremely buggy and/or badly-written. If you find any bugs/extremely bad writing that look fixable, please tell me; the hardest part about solving problems is not how to fix the issue, but how to find it.
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
### Loops ###
For loops:

    ## Default-step for loop:
    for $varname : $start, $end {
        print($varname);
        ## other stuff
    };
    ## Set-step for loop:
    for $varname : $start, $end, $step {
        ## do stuff
    };
    ## Dynamic-step for loop
    for $varname : $start, $end [$varname+=$varname/2;] {
        ## do stuff
    };
While loops:

    while $conditions==true {
        ## do stuff
    };
The loop will repeat until $some_conditions is false. The conditions are re-evaluated after each loop.
### Function definition ###

    function funcName : $arg1, $arg2
    {
	    ## do stuff
	    return $arg1;
	};
### Types ###
Although they use the keyword "type", types could more accurately be called "templates." Once defined, a type can be used to create any number of instances. A type is declared like this:

    type type_name : $arg1=default_value, $arg2=default_value {
	    @method1 : $arg {
		    ## do something
		    return $arg*$arg1;
		};
		@method2 : null {
			## stuff
		};
	};
### Instances ###
Instances are created and used like this:

    new type_name: instance_name(args);
    instance_name > method (arg);
### Arrays ###
The syntax for array creation and access is exactly like it is in Lua:

    $array = {1, 2, 3, 4};
    $indexedArray = {["a"] = 1, ["b"] = 2, ["c"] = 3};
    $foo = $array[1]; ## result: 1
    $bar = $indexedArray["b"]; ## result: 2
The array.index syntax from Lua is not supported yet, but it will be soon.
### Output ###
To print things, you can use either this:

    print("stuff");
or this:

    print "stuff";
Those methods are equivalent, although the second is more prone to bugs.
### File I/O ###
File handles are uncomplicated to create - once initialized, they can be used to read from or write to a file any number of times. They can be closed, but there is no need to, as Lua does so automatically.

To create a file handle, use *open*:

    open <"file_name"> : handle;
The contents of the resulting handle can be read into a string:

    handle -> $str;

    ## The $ is optional, so
    ## handle -> str;
    ## would work just as well.
In that example, all the text contained in *handle*'s file is copied to *$str*.

Writing to a file is similar:

    handle <- "content to be written";
The content does not have to be a string - any data type or variable can be written except null values.