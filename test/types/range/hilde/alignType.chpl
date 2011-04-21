// alignType.chpl
//
// Tests the type returned by the align operator.

writeln(typeToString((1:int.. by 10 align 3:int).type));
writeln(typeToString((1:int.. by 10 align 3:int(8)).type));
writeln(typeToString((1:int.. by 10 align 3:int(16)).type));
writeln(typeToString((1:int.. by 10 align 3:int(32)).type));
writeln(typeToString((1:int(8).. by 10 align 3:int).type));
writeln(typeToString((1:int(8).. by 10 align 3:int(8)).type));
writeln(typeToString((1:int(8).. by 10 align 3:int(16)).type));
writeln(typeToString((1:int(8).. by 10 align 3:int(32)).type));
writeln(typeToString((1:int(16).. by 10 align 3:int).type));
writeln(typeToString((1:int(16).. by 10 align 3:int(8)).type));
writeln(typeToString((1:int(16).. by 10 align 3:int(16)).type));
writeln(typeToString((1:int(16).. by 10 align 3:int(32)).type));
writeln(typeToString((1:int(32).. by 10 align 3:int).type));
writeln(typeToString((1:int(32).. by 10 align 3:int(8)).type));
writeln(typeToString((1:int(32).. by 10 align 3:int(16)).type));
writeln(typeToString((1:int(32).. by 10 align 3:int(32)).type));
writeln(typeToString((1:int(64).. by 10 align 3:int).type));
writeln(typeToString((1:int(64).. by 10 align 3:int(8)).type));
writeln(typeToString((1:int(64).. by 10 align 3:int(16)).type));
writeln(typeToString((1:int(64).. by 10 align 3:int(32)).type));
writeln(typeToString((1:int(64).. by 10 align 3:int(64)).type));
writeln(typeToString((1:int(64).. by 10 align 3:uint).type));
writeln(typeToString((1:int(64).. by 10 align 3:uint(8)).type));
writeln(typeToString((1:int(64).. by 10 align 3:uint(16)).type));
writeln(typeToString((1:int(64).. by 10 align 3:uint(32)).type));

writeln(typeToString((1:uint.. by 10 align 3:uint).type));
writeln(typeToString((1:uint.. by 10 align 3:uint(8)).type));
writeln(typeToString((1:uint.. by 10 align 3:uint(16)).type));
writeln(typeToString((1:uint.. by 10 align 3:uint(32)).type));
writeln(typeToString((1:uint(8).. by 10 align 3:int).type));
writeln(typeToString((1:uint(8).. by 10 align 3:int(8)).type));
writeln(typeToString((1:uint(8).. by 10 align 3:int(16)).type));
writeln(typeToString((1:uint(8).. by 10 align 3:int(32)).type));
writeln(typeToString((1:uint(16).. by 10 align 3:int).type));
writeln(typeToString((1:uint(16).. by 10 align 3:int(8)).type));
writeln(typeToString((1:uint(16).. by 10 align 3:int(16)).type));
writeln(typeToString((1:uint(16).. by 10 align 3:int(32)).type));
writeln(typeToString((1:uint(32).. by 10 align 3:uint).type));
writeln(typeToString((1:uint(32).. by 10 align 3:uint(8)).type));
writeln(typeToString((1:uint(32).. by 10 align 3:uint(16)).type));
writeln(typeToString((1:uint(32).. by 10 align 3:uint(32)).type));
writeln(typeToString((1:uint(64).. by 10 align 3:uint).type));
writeln(typeToString((1:uint(64).. by 10 align 3:uint(8)).type));
writeln(typeToString((1:uint(64).. by 10 align 3:uint(16)).type));
writeln(typeToString((1:uint(64).. by 10 align 3:uint(32)).type));
writeln(typeToString((1:uint(64).. by 10 align 3:uint(64)).type));
