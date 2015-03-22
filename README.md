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
