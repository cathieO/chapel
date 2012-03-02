/*
 * File I/O Primer
 */

/*
   First example: Textual Array I/O
   Second and Third examples: Binary I/O
   Fourth example: reading UTF-8 lines and printing them out.
   Fifth example: error handling.
   Sixth example: object-at-a-time writing.
   Seventh example: binary I/O with bits at a time
*/

config var n = 9,            // the problem size for example 1
           filename = "Arr.dat";  // the filename for writing/reading the array
config const num = 1*1024*1024;
config const example = 0;
config const testfile = "test.bin";

use IO;

/* Example 1
 * This is a simple example of using file I/O in Chapel.
 *
 * It initializes an array and writes its size and data to a file.  It
 * then opens the file, uses the size in the file to declare a new
 * domain and array, and reads in the array data.
 */
if example == 0 || example == 1 {
  const ADom = [1..n, 1..n];  // Create a domain of the specified problem size

  // Create and initialize an array of the specified size
  var A: [ADom] real = [(i,j) in ADom] i + j/10.0;
  
  // Write the problem size and array out to the specified filename
  writeSquareArray(n, A, filename);
  
  // Read an array in from the specified filename, storing in a new variable, B
  var B = readArray(filename);
  
  // Print out B as a debugging step
  writeln("B is:\n", B);
  
  //
  // verify that A and B contain the same values and print success or failure
  //
  const numErrors = + reduce [i in ADom] (A(i) != B(i));

  if (numErrors > 0) {
    writeln("FAILURE");
  } else {
    writeln("SUCCESS");
  }
}


//
// this procedure writes a square array out to a file
//
proc writeSquareArray(n, X, filename) {
  // Create and open an output file with the specified filename in write mode
  var outfile = open(filename, iomode.w);
  var writer = outfile.writer();

  // Write the problem size in each dimension to the file
  writer.writeln(n, " ", n);

  // write out the array itself
  writer.write(X);

  // close the file
  writer.close();
  outfile.close();
}


//
// This procedure reads a new array out of a file and returns it
//
proc readArray(filename) {
   // Open an input file with the specified filename in read mode
  var infile = open(filename, iomode.r);
  var reader = infile.reader();

  // Read the number of rows and columns in the array in from the file
  var m = reader.read(int), 
      n = reader.read(int);

  // Declare an array of the specified dimensions
  var X: [1..m, 1..n] real;

  //
  // Read in the array elements one by one (eventually, you should be
  // able to read in the array wholesale, but this isn't currently
  // supported.
  //
  for i in 1..m do
    for j in 1..n do
      reader.read(X(i,j));

  // Close the file
  reader.close();
  infile.close();

  // Return the array
  return X;
}


/*
   In Examples 2 and 3, we will write numbers 0..n-1 to a file in binary,
   and then we'll open it up, and read the numbers in reverse,
   just to show how to 'seek' in a file.

   We show two versions of this example; a simple version, and
   a slightly more complicated version that has some performance hints.
*/

if example == 0 || example == 2 {
  writeln("Running Example 2");

  // Here comes the simple version!

  // First, open up a test file. Chapel's I/O interface allows
  // us to open regular files, temporary files, memory, or file descriptors;
  // we can also specify access with "r", "w", "r+", "w+", etc.
  var f = open(testfile, iomode.wr);

  /* Since the typical 'file position' design leads to race conditions
   * all over, the Chapel I/O design separates a file from a channel.
   * A channel is a buffer to a particular spot in a file. Channels
   * can have a start and and end, so that if you're doing parallel I/O
   * to different parts of a file with different channels, you can
   * partition the file to be assured that they do not interfere.
   */

  {
    var w = f.writer(kind=ionative); // get a binary writing channel for the start of the file.

    for i in 0..#num { // for each i in [0,n)
      var tmp:uint(64) = i:uint(64);
      w.write(tmp); // writing a uint(64) will write 8 bytes.
    }

    // Now w goes out of scope, it will flush anything that is buffered.
    // Channels are reference-counted, so it should be easy, but if you want to make sure,
    // you can close the channel.
    w.close();
  }

  // OK, now we have written our data file. Now read it backwards.
  // Note -- this could be a forall loop to do I/O in parallel!
  for i in 0..#num by -1 {
    var r = f.reader(kind=ionative, start=8*i, end=8*i+8);
    var tmp:uint(64);
    r.read(tmp);
    assert(tmp == i:uint(64));
    r.close();
  }

  // Now close the file. Like channels, files are reference-counted,
  // and so should close when they go out of scope, but we close it
  // here anyway to be sure.
  f.close();

  // Finally, we can remove the test file.
  unlink(testfile);
}

if example == 0 || example == 3 {
  writeln("Running Example 3");

  /* Here comes a faster version of example 2, using some hints.
     This time we're not going to use a temporary file, because
     we want to open it twice for performance reasons.
     If you want to measure the performance difference, try:
       time ./fielIOv2 --example=2
       time ./fielIOv2 --example=3
   */

  // First, open up a file and write to it.
  {
    var f = open(testfile, iomode.wr);
    /* When we create the writer, suppling locking=false will do unlocked I/O.
       That's fine as long as the channel is not shared between tasks.
      */
    var w = f.writer(kind=ionative, locking=false);

    for i in 0..#num {
      var tmp:uint(64) = i:uint(64);
      w.write(tmp);
    }

    w.close();
    f.close();
  }

  /* Now that we've created the file, when we open it for
     read access and hint 'random access' and 'keep data cached/assume data is cached',
     we can optimize better (using mmap, if you like details).
   */
  {
    var f = open(testfile, iomode.r, hints=HINT_RANDOM|HINT_CACHED);

    // Note -- this could be a forall loop to do I/O in parallel!
    forall i in 0..#num by -1 {
      /* When we create the reader, suppling locking=false will do unlocked I/O.
         That's fine as long as the channel is not shared between tasks;
         here it's just used as a local variable, so we are O.K. 
        */
      var r = f.reader(kind=ionative, locking=false, start=8*i, end=8*i+8);
      var tmp:uint(64);
      r.read(tmp);
      assert(tmp == i:uint(64));
      r.close();
    }

    f.close();
  }

  // Finally, we can remove the test file.
  unlink(testfile);
}

/*
   In Example 4, we show that it's easy to read the lines in a file,
   including UTF-8 characters.
*/
if example == 0 || example == 4 {
  writeln("Running Example 4");

  var f = open(testfile, iomode.wr);
  var w = f.writer();

  w.writeln("Hello");
  w.writeln("This");
  w.writeln(" is ");
  w.writeln(" a test ");
  // We only write the UTF-8 characters if unicode is supported,
  // and that depends on the current unix locale environment
  // (e.g. setting the environment variable LC_ALL=C will disable unicode support).
  // Note that since UTF-8 strings are C strings, this should work
  // even in a C locale. We don't do it all the time for testing sanity reasons.
  if unicodeSupported() then w.writeln(" of UTF-8 Euro Sign: €");

  // flush buffers, close the channel.
  w.close();
  
  var r = f.reader();
  var line:string;
  while( r.readline(line) ) {
    write("Read line: ", line);
  }
  r.close();

  // Or, if we just want all the lines in the file,
  // we can use file.lines, and we don't even have to make a reader:
  for line in f.lines() {
    write("Read line: ", line);
  }

  f.close();
  unlink(testfile);
}

/*
   In Example 5, we show that error handling is possible
   with the new I/O routines. Maybe one day this strategy will
   be replaced by exceptions, but until then... Chapel programs
   can still respond to errors.
   
*/
if example == 0 || example == 5 {
  writeln("Running Example 5");

  // Error handling.
  var err = ENOERR;
  // Who knows, maybe 1st unlink succeeds.
  unlink(testfile, error=err);

  // File does not exist by now, for sure.
  unlink(testfile, error=err);
  assert(err == ENOENT);
  
  // What happens if we try to open a non-existant file?
  var f = open(testfile, iomode.r, error=err);
  assert(err == ENOENT);

  /* Note that if an error= argument is not supplied to an
     I/O function, it will call ioerror, which will
     in turn halt with an error message.
   */
}

/*
   In Example 6, we demonstrate that output from multiple tasks
   can use the same channel, and each write() call will be
   completed entirely before another one is allowed to begin.
*/
if example == 0 || example == 6 {
  writeln("Running Example 6");

  forall i in 1..4 {
    writeln("This should be a chunk: {", "\n a", "\n b", "\n}");
  }

  record MyThing {
    proc writeThis(w:Writer) {
      w.writeln("This should be a chunk: {");
      w.writeln(" a");
      w.writeln(" b");
      w.writeln("}");
    }
  }

  forall i in 1..4 {
    var t:MyThing;
    write(t);
  }
}

/*
   In Example 7, we demonstrate bit-level I/O.
 */
if example == 0 || example == 7 {
  writeln("Running Example 7");

  var f = open(testfile, iomode.wr);

  {
    var w = f.writer(kind=ionative);

    // Write 011 0110 011110000
    w.writebits(0b011, 3);
    w.writebits(0b0110, 4);
    w.writebits(0b011110000, 9);
    w.close();
  }

  // Try reading it back the way we wrote it.
  {
    var r = f.reader(kind=ionative);
    var tmp:uint(64);

    r.readbits(tmp, 3);
    assert(tmp == 0b011);

    r.readbits(tmp, 4);
    assert(tmp == 0b0110);

    r.readbits(tmp, 9);
    assert(tmp == 0b011110000);
  }

  // Try reading it back all as one big chunk.
  // Read 01101100 11110000
  {
    var r = f.reader(kind=ionative);
    var tmp:uint(8);

    r.read(tmp);
    assert(tmp == 0b01101100);

    r.read(tmp);
    assert(tmp == 0b11110000);
  }
}

