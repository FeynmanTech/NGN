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
Instances are created and used like this:

    new type_name: instance_name(args);
    instance_name > method (arg);
To print things, you can use either this:

    print("stuff");
or this:

    print "stuff";
Those methods are equivalent, although the second is more prone to bugs.
