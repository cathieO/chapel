// Like hplExample1 but without using the Panel2D structure (or counted
// ranges).

use Random;
use Norm;

// calculate C = C - A * B.
def dgemm(
    p : int,    // number of rows in A
    q : int,    // number of cols in A, number of rows in B
    r : int,    // number of cols in B
    A : [1..p, 1..q] ?t,
    B : [1..q, 1..r] t,
    C : [1..p, 1..r] t)
{
    // Calculate (i,j) using a dot product of a row of A and a column of B.
    for i in 1..p {
        for j in 1..r {
            for k in 1..q {
                C[i,j] -= A[i, k] * B[k, j];
            }
        }
    }
}


// do unblocked-LU decomposition within the specified panel, update the
// pivot vector accordingly
def panelSolve(
    A : [] ?t,
    panel : domain(2),
    piv : [] int)
{
    var pnlRows = panel.dim(1);
    var pnlCols = panel.dim(2);

    // Ideally some type of assertion to ensure panel is embedded in A's
    // domain
    assert(piv.domain.dim(1) == A.domain.dim(1));

    // iterate through the columns
    for k in pnlCols {
        var col = panel[k.., k..k];

        // The pivot is the element with the largest absolute value.
        var ( , loc) =
            maxloc reduce(abs(A(col)), col);
        var pivotRow = loc(1);
        var pivot = A[pivotRow, k];

        // Swap the current row with the pivot row
        piv[k] <=> piv[pivotRow];
        A[k, ..] <=> A[pivotRow, ..];
        
        if(pivot == 0) then {
            halt("Matrix can not be factorized");
        }
        
        // divide all values below and in the same col as the pivot by
        // the pivot
        if k+1 <= pnlRows.high {
            A(col)[k+1.., k..k] /= pivot;
        }

        // update all other values below the pivot
        if k+1 <= pnlRows.high && k+1 <= pnlCols.high {
            forall (i,j) in panel[k+1.., k+1..] {
                A[i,j] -= A[i,k] * A[k,j];
            }
        }
    }
}

// Update the block row (tr for top-right) portion of the matrix in a blocked
// LU decomposition.  Each step of the LU decomposition will solve a block
// (tl for top-left) portion of a matrix. This function solves the rows to the
// right of the block.
def updateBlockRow(A : [] ?t, tl : domain(2), tr : domain(2))
{
    var tlRows = tl.dim(1);
    var tlCols = tl.dim(2);
    var trRows = tr.dim(1);
    var trCols = tr.dim(2);

    assert(tlCols == trRows);

    for i in trRows {
        forall j in trCols {
            for k in tlRows.low..i-1 {
                A[i, j] -= A[i, k] * A[k,j];
            }
        }
    }
}

// blocked LU factorization with pivoting for matrix augmented with vector of
// RHS values.
def LUFactorize(n : int, A : [1..n, 1..n+1] real, piv : [1..n] int) {
    const ARows = A.domain.dim(1);
    const ACols = A.domain.dim(2);

    param blkSize = 3;
    piv = 1..n;

    /*
       The following diagram illustrates how we partition the matrix.  The
       program defines a number of ranges (specified in the legend) to span
       various portions of the array.

       We use these ranges to find subdomains of the array (labeled in the
       picture as tl, tr, bl, and br) there's an additional domain (not shown)
       l that is the union of tl and bl.

                (point blk, blk)
       +-------//------------------+ -----------   LEGEND:
       |......//...................|          |      1: blockRange
       |.....//....................|          |      2: trailingRows
       |....+-----+----------------| ------.  |      3: unfactoredRows
       |....|     |                |  |    |  |      4: trailingCols
       |....| tl  |      tr        |  1    |         5: unfactoredCols
       |....|     |                |  |    |  7      6: ARows
       |....+-----+----------------| ---             7: ACols
       |....|     |                |  |    3  |      
       |....|     |                |          |      
       |....| bl  |      br        |  2    |  |
       |....|     |                |       |  |
       |....|     |                |  |    |  |
       +----+-----+----------------+ ------------

       |    |    |                 |    
       |    |-1 -|------ 4 --------|
       |    |                      |
       |    `--------- 5 ----------|
       |                           |
       |------------ 6 ------------|
       |                           |
    */

    for blk in 1..n by blkSize {
        const crntBlkSize = min(blkSize, n-blk+1);

        const blockRange     = blk..blk+crntBlkSize-1;
        const trailingRows   = (blk+crntBlkSize..ARows.high);
        const unfactoredRows = (blk..ARows.high);
        const trailingCols   = (blk+crntBlkSize..ACols.high);
        const unfactoredCols = (blk..ACols.high);

        var tl = [blockRange, blockRange];
        var tr = [blockRange, trailingCols];
        var bl = [trailingRows, blockRange];
        var br = [trailingRows, trailingCols];
        var l  = [unfactoredRows, blockRange];
        
        // Now that we've sliced and diced A properly do the blocked-LU
        // computation:
        panelSolve(A, l, piv);
        updateBlockRow(A, tl, tr);

        // update trailing submatrix (if there)
        if(br.numIndices > 0) {
            dgemm(trailingRows.length, blockRange.length, trailingCols.length,
                  A(bl), A(tr), A(br));
          }
      }
}

// -------------------------------------------------------------------------- 
//   TESTING SYSTEM:
// -------------------------------------------------------------------------- 
def matrixMult(
    const m : int,
    const p : int,
    const n : int,
    const A : [1..m, 1..p],
    const B : [1..p, 1..n],
    C : [1..m, 1..n])
{
    C = 0;

    for (i,j,k) in [C.domain.dim(1), C.domain.dim(2), 1..p] {
        C[i,j] += A[i,k] * B[k,j];
    }
}

// given a matrix in A in form: [L, U] multiply the L and U parts into
// a resulting matrix C.
def selfMult(n : int, A : [1..n,1..n] real, C : [1..n,1..n] real) {
    C = 0;

    forall (i,j) in C.domain {
        if(i <= j) {
            for k in 1..i-1 {
                C[i,j] += A[i,k] * A[k,j];
            }
            C[i,j] += A[i,j];
        }
        else if(j <= i){
            for k in 1..j {
                C[i,j] += A[i,k] * A[k,j];
            }
        }
    }
}

// given a matrix and a permuatations vector apply the permutations
// QUESTION: I'm intending vectorIn to be passed by value in this instance
// (since I modify it in the function but I don't want the result sent out).
// is this function doing the trick?
def permuteMatrix(matrix : [?dmn], in vector) {
    //var pdmn : sparse subdomain(dmn);
    var pdmn =
        [1..vector.domain.dim(1).length, 1..vector.domain.dim(1).length];
    var p : [pdmn] int;
    //p.IRV = 0;

    // construct permutation matrix
    forall i in vector {
        //pdmn.add((i, vector[i]));
        p[i, vector[i]] = 1;
    }

    // multiply permutation matrix times the matrix
    var permuted = matrix;

    matrixMult(
        dmn.dim(1).length,
        dmn.dim(1).length,
        dmn.dim(2).length,
        p, matrix, permuted);

    matrix = permuted;
}

def permuteBack(matrix : [?dmn], in piv) {
    // this just does a bubblesort of the permutation vector swapping the
    // rows of the matrix alongside. Yes the performance here will be horrible,
    // not to mention all the data being shuffled around, but this function
    // is in the test system so it's excusable.

    const low  = piv.domain.dim(1).low;
    const high = piv.domain.dim(1).high;

    for i in piv.domain {
        for j in low..high-1 {
            if piv[j+1] < piv[j] {
                piv[j] <=> piv[j+1];
                matrix[j, ..] <=> matrix[j+1, ..];
            }
        }
    }
}

def permuteBackVec(vector : [?dmn], in piv) {
    const low  = piv.domain.dim(1).low;
    const high = piv.domain.dim(1).high;

    for i in piv.domain {
        for j in low..high-1 {
            if piv[j+1] < piv[j] {
                piv[j] <=> piv[j+1];
                vector[j] <=> vector[j+1];
            }
        }
    }
}


// matrix-vector multiplication, solve equation A*x-y
def gaxpyMinus(
    n : int,
    m : int,
    A : [1..n, 1..m],
    x : [1..m],
    y : [1..n])
{
    var res : [1..n] real;

    for i in 1..n {
        for j in 1..m {
            res[i] += A[i,j]*x[j];
        }
    }

    for i in 1..n {
        res[i] -= y[i];
    }

    return res;
}


def backwardSub(
    n : int,
    A : [1..n, 1..n] real,
    b : [1..n] real)
{
    var x : [b.domain] real;

    for i in [b.domain by -1] do {
        x[i] = b[i];

        for j in [i+1..b.domain.high] do {
            x[i] -= A[i,j] * x[j];
        }

        x[i] /= A[i,i];
    }

    return x;
}



def test_permuteMatrix(rprt = true) : bool {
    // test one of the testing functions: permuteMatrix (is this getting a
    // little too meta here?)

    param n = 10;
    var rand = new RandomStream();

    // this n by n array is filled so each element is assigned to its
    // row number. This test will permute these elements, keeping a pivot
    // vector alongside.
    var A : [1..n, 1..n] int = [(i,j) in [1..n, 1..n]] i;
    var piv : [1..n] int = [i in 1..n] i;
    var AOrig = A;

    // do 100 random swaps of A
    for i in 1..100 {
        var randRow1 = (rand.getNext() * 10000):int % n + 1;
        var randRow2 = (rand.getNext() * 10000):int % n + 1;

        A[randRow1, ..] <=> A[randRow2, ..];
        piv[randRow1] <=> piv[randRow2];
    }

    delete rand;

    // permute original version of A
    permuteMatrix(AOrig, piv);

    // calculate and report results. Calculate by comparing the original
    // version of A which we just permuted to swapped version.
    if rprt then write("test_permuteMatrix: ");
    if & reduce(AOrig == A) then {
        if rprt then writeln("PASSED");
        return true;
    } else {
        if rprt then writeln("FAILED");
        return false;
    }
}

def test_panelSolve(rprt = true) : bool {
    var rand = new RandomStream();

    var piv : [1..8] int = [i in 1..8] i;
    var A : [1..8, 1..9] real =
        [(i,j) in [1..8, 1..9]] (rand.getNext() * 10000):int % 100 + 1;
    var AOrig = A;

    var AOrig2 = A;

    delete rand;

    // grab a panel and solve it
    param offset = 3;
    param blkSize = 3;
    var pnl = A.domain[offset.., offset..offset+blkSize];

    panelSolve(A, pnl, piv);

    // to test multiply the L and U parts of the top portion of the panel
    // (just the block) together and check that the result matches the
    // block on the original matrix when permuted.
    var C : [1..blkSize, 1..blkSize] real;
    var blockD =
        [offset..offset+blkSize-1, offset..offset+blkSize-1];
    selfMult(blkSize, A(blockD), C);
    permuteMatrix(AOrig, piv);

    // calculate and report results.
    if rprt then write("test_panelSolve: ");
    // NOTE: The reduce statement requires this heavy parenthesization,
    // if I just do "if(& reduce AOrig(blockD) == C) {" it'll cause a compiler
    // error.
    if(& reduce ((AOrig(blockD)) - C <= .001)) {
        if rprt then writeln("PASSED");
        return true;
    } else {
        if rprt then writeln("FAILED");
        return false;
    }
}

def test_updateBlockRow(rprt = true) : bool {
    var rand = new RandomStream();

    // construct a matrix A = [X | Y], where X is an already LU-factorized
    // submatrix and Y is the block row we wish to update and test
    var randomOffset : int = (rand.getNext() * 100):int;
    var randomHeight : int = (rand.getNext() * 100):int + 1;
    var randomWidth  : int = (rand.getNext() * 100):int + randomHeight;
    var A : [randomOffset..randomOffset+randomHeight-1,
             randomOffset..randomOffset+randomWidth-1] real;
    rand.fillRandom(A);
    delete rand;
    var OrigA = A;
    
    // capture X and Y
    var X = [randomOffset..randomOffset+randomHeight-1,
             randomOffset..randomOffset+randomHeight-1];
    var Y = [randomOffset..randomOffset+randomHeight-1,
             randomOffset+randomHeight..(randomWidth-randomHeight)];

    // apply the update block row function
    updateBlockRow(A, X, Y);

    // do a matrix multiply of L and U to obtain the original values in
    // the block row
    var recalc : [randomOffset..randomOffset+randomHeight-1,
                  randomOffset+randomHeight..(randomWidth-randomHeight)] real;
    forall (i,j) in recalc.domain {
        for k in randomOffset..i-1 {
            recalc[i,j] += A[i,k] * A[k,j];
        }
        recalc[i,j] += A[i,j];
    }

    // calculate and report results
    if rprt then write("test_updateBlockRow: ");
    if(& reduce (abs(recalc - (OrigA(recalc.domain))) <= 0.1)) {
        if rprt then writeln("PASSED");
        return true;
    }
    else {
        if rprt then writeln("FAILED");
        return false;
    }
}

def test_LUFactorizeNorms(
    n    : int,
    A    : [1..n, 1..n] real,
    b    : [1..n] real,
    AHat : [1..n, 1..n] real,
    bHat : [1..n] real,
    piv  : [1..n] int) : bool
{
    var x : [1..n] real;

    // use backward substitution to solve the system of equations.
    x = backwardSub(n, AHat, bHat);

    // calculate residuals (equations at bottom of this page
    //     http://www.netlib.org/benchmark/hpl/algorithm.html):

    var axmbNorm =
        norm(gaxpyMinus(n, n, A([1..n, 1..n]), x, b), normType.normInf);

    var a1norm   = norm(A([1..n, 1..n]), normType.norm1);
    var aInfNorm = norm(A([1..n, 1..n]), normType.normInf);
    var x1Norm   = norm(x, normType.norm1);
    var xInfNorm = norm(x, normType.normInf);

    const eps = 2.0e-15;

    var resid1 = axmbNorm / (eps * a1norm * n);
    var resid2 = axmbNorm / (eps * a1norm * x1Norm);
    var resid3 = axmbNorm / (eps * aInfNorm * xInfNorm);

    return max(resid1, resid2, resid3) <= 16.0;
}

def test_LUFactorize(rprt = true, seed = -1) : bool {
    // construct a matrix of random size with random values 
    var rand = new RandomStream(seed);

    var randomN : int = (rand.getNext() * 10):int + 1;
    var A : [1..randomN, 1..randomN+1] real;
    for idx in A.domain do A[idx] = rand.getNext() * 2.0 - 1.0;

    delete rand;

    // save a copy
    var origA = A;

    var piv : [1..randomN] int;

    LUFactorize(randomN, A, piv);
    
    var C : [1..randomN, 1..randomN] real;
    selfMult(randomN, A[1..randomN,1..randomN], C);
    permuteBack(C, piv);

    // test using norms

    var arg_n    = randomN;
    var arg_A    : [1..arg_n, 1..arg_n] real;
    var arg_b    : [1..arg_n] real;
    var arg_AHat : [1..arg_n, 1..arg_n] real;
    var arg_bHat : [1..arg_n] real;
    var arg_piv  : [1..arg_n] int;

    arg_A = origA[1..randomN, 1..randomN];
    arg_b = origA[1..randomN, randomN+1];
    arg_AHat = A[1..randomN, 1..randomN];
    arg_bHat = A[1..randomN, randomN+1];
    arg_piv = piv;


    if test_LUFactorizeNorms(
        randomN, arg_A, arg_b, arg_AHat, arg_bHat, arg_piv)
    {
        if rprt then writeln("PASSED");
        return true;
    } else {
        if rprt then writeln("FAILED");
        return false;
    }
}

def main() {
    var result = true;
    write("test_permuteMatrix: ");
    for i in 1..100 do
        result &= test_permuteMatrix(rprt=false);
    if result then writeln("PASSED");
    else writeln("FAILED");

    var numPassed = 0;
    write("test_panelSolve: ");
    for i in 1..1000 do
        numPassed += test_panelSolve(rprt=false);
    writeln(numPassed, " PASSED, ", 1000-numPassed, " FAILED");

    numPassed = 0;
    write("test_updateBlockRow: ");
    for i in 1..100 do
        numPassed += test_updateBlockRow(rprt=false);
    writeln(numPassed, " PASSED, ", 100-numPassed, " FAILED");

    numPassed = 0;
    write("test_LUFactorize: ");
    for i in 1..1000 do
        numPassed += test_LUFactorize(rprt=false, i * 1000 + 1);
    writeln(numPassed, " PASSED, ", 1000-numPassed, " FAILED");
}

