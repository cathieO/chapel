proc main {
  var D1 = [1..10];
  var D2 = [1..10];
  var A1: [i in D1] int = i;
  var A2: [D2] => A1;
  writeln("A1=", A1);
  writeln("A2=", A2);
  D1 = [1..11];
  writeln("A1=", A1);
  writeln("A2=", A2);
}
