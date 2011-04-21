// align.chpl
//
// Tests representation limits for the align operator.

const minS = min(int);
const maxS = max(int);
const maxU = max(uint);
const nI = -2**53;
const pI = 2:uint(64)**63;

writeln(1:int.. by 10 align minS);
writeln(1:int.. by 10 align maxS);
writeln(1:int.. by 10 align (maxS+1));
// writeln(1:int.. by 10 align maxU);
writeln(1:int.. by 10 align nI);
// writeln(1:int.. by 10 align pI);
writeln(1:int(8).. by 10 align minS);
writeln(1:int(8).. by 10 align maxS);
writeln(1:int(8).. by 10 align (maxS+1));
// writeln(1:int(8).. by 10 align maxU);
writeln(1:int(8).. by 10 align nI);
// writeln(1:int(8).. by 10 align pI);
writeln(1:int(16).. by 10 align minS);
writeln(1:int(16).. by 10 align maxS);
writeln(1:int(16).. by 10 align (maxS+1));
// writeln(1:int(16).. by 10 align maxU);
writeln(1:int(16).. by 10 align nI);
// writeln(1:int(16).. by 10 align pI);
writeln(1:int(32).. by 10 align minS);
writeln(1:int(32).. by 10 align maxS);
writeln(1:int(32).. by 10 align (maxS+1));
// writeln(1:int(32).. by 10 align maxU);
writeln(1:int(32).. by 10 align nI);
// writeln(1:int(32).. by 10 align pI);
writeln(1:int(64).. by 10 align minS);
writeln(1:int(64).. by 10 align maxS);
writeln(1:int(64).. by 10 align (maxS+1));
writeln(1:int(64).. by 10 align maxU);
writeln(1:int(64).. by 10 align nI);
// writeln(1:int(64).. by 10 align pI);
// writeln(1:uint.. by 10 align minS);
// writeln(1:uint.. by 10 align maxS);
// writeln(1:uint.. by 10 align (maxS+1));
writeln(1:uint.. by 10 align maxU);
// writeln(1:uint.. by 10 align nI);
// writeln(1:uint.. by 10 align pI);
writeln(1:uint(8).. by 10 align minS);
writeln(1:uint(8).. by 10 align maxS);
writeln(1:uint(8).. by 10 align (maxS+1));
// writeln(1:uint(8).. by 10 align maxU);
writeln(1:uint(8).. by 10 align nI);
// writeln(1:uint(8).. by 10 align pI);
writeln(1:uint(16).. by 10 align minS);
writeln(1:uint(16).. by 10 align maxS);
writeln(1:uint(16).. by 10 align (maxS+1));
// writeln(1:uint(16).. by 10 align maxU);
writeln(1:uint(16).. by 10 align nI);
// writeln(1:uint(16).. by 10 align pI);
// writeln(1:uint(32).. by 10 align minS);
// writeln(1:uint(32).. by 10 align maxS);
// writeln(1:uint(32).. by 10 align (maxS+1));
writeln(1:uint(32).. by 10 align maxU);
// writeln(1:uint(32).. by 10 align nI);
// writeln(1:uint(32).. by 10 align pI);
// writeln(1:uint(64).. by 10 align minS);
// writeln(1:uint(64).. by 10 align maxS);
// writeln(1:uint(64).. by 10 align (maxS+1));
writeln(1:uint(64).. by 10 align maxU);
// writeln(1:uint(64).. by 10 align nI);
writeln(1:uint(64).. by 10 align pI);

