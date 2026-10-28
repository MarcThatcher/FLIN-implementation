# README -- FLIN to INPLA compiler

Bug reports: via the issues page on this repository, or to my email address which can be found at https://marcthatcher.github.io/contact.html.

(For simplicity the term "FLIN" is used to refer to both the language and the compiler below.)

This implementation is for demonstration purposes only and should be used after reading the submitted paper and the below.  (Some of the description in the implementation section of the abstract is now out of date.)

FLIN compiles to INPLA so to run programs, INPLA must be installed.
See https://github.com/inpla/inpla for the source code (GCC or similar required) and instructions.
See also comments at end of this document re INPLA.

To use FLIN:
- Download at least Lexer.hs, Parser.hs, Trans.hs and Main.hs .
- Compile FLIN using ghc: ghc -O2 -o flin Main.hs .
- The compiler can then be run as flin [-imm] [-hof] [-bat] <filename>.txt .
- Each of the flags is optional. Multiple can be used; the order is ignored.

The above works on MacOS/Unix and Windows but INPLA requires MacOS/Unix so the following steps assume that.  (This was developed on Windows system using Windows Terminal/Ubuntu to run INPLA.  It has been checked on a Mac but most testing was done within Windows.)

The -bat flag runs FLIN in batch mode, otherwise it enters interactive mode (see below).


## 1) Interactive mode
In interactive mode, FLIN reads the filename given and translates all the definitions therein.

The input file must be a plain text file (`*.txt`) with one function definition per line.
Because function definitions do not explicitly state the numbers of outputs they have, a definition which implies it must be given before one that does not.
Therefore the base case of a function must be given before the recursive case.
For example the following compiles:
```text
 even(Z)    = True
 even(S(x)) = odd(x)
 odd(S(x))  = even(x)
 odd(Z)     = False
```
because `even(Z)= True` tells the compiler that there is a single output.
If the first two lines were swapped, it would not compile because the number of outputs of `even` based on `even(S(x)) = odd(x)` depends on the number of outputs of `odd(x)`, which is not yet known.
Note that the reverse order for `odd` (above) works because the first instance is defined in terms of something whose number outputs is known.
The order of definitions in the compiled program may not be the same as the input as FLIN first outputs in-built definitions (dealing with lambda application), then rules including numerals, then others.

Functions must start with lower-case letters and can include numbers but not other punctuation.
(Sometimes other punctuation will be accepted but may clash with internally generated functions for certain flags, or not be accepted by INPLA.)
Constructors start with capital letters and are otherwise the same.
Variable (port) labels have same rules as functions.

Comments are full lines only and start with `--`, e.g. 
``` -- This is a comment.```
is valid, but
``` id(Z) = Z -- This will cause an error```
will cause an error.

Spaces and blank lines are ignored.
In interactive mode, the file should only include comments, blank lines and function definitions.

The output in interactive mode is made up of:
1. A copy of the input file.
2. The resulting INPLA rules, including one to deal with lambda-application interactions.

Rules can be cut and pasted in INPLA one at a time or all at once. 
Make sure not to copy anything else, such as the FLIN input code, as INPLA will not accept it.
If you paste mutiple rules into INPLA you may get a warning that this `may result in the unexpected execution of commands`. (This may just be a Windows thing.) In my experience, this can be ignored but the pasting often occurs all over the screen which is harmless but somewhat disconcerting.

You can then enter a single FLIN term at the prompt which will be translated to INPLA.
Cutting and pasting that into INPLA will evaluate it.
Unless asked for, INPLA does not give the resulting net. 
Either enter (one at a time or together split by spaces) the name(s) of the port(s) you wish to see the resulting nets at, or enter `ifce` to see the entire net.
Further FLIN terms can be entered; enter :Q to quit.


## 2) Batch mode
(Please read the explanation for interactive mode before reading this.)
In batch mode, the input file should be as for interactive mode but following the function definitions there must be a term to be evaluated.
It is assumed that the term is the final line in the file so there cannot be anything after it including blank lines and comments.

The compiler will output, in the same directory it is in, a file with the same name as the input file but with the extension `.in`.

INPLA run with the -f flag will read the entire file, evaluate the net and print the nets attached to all output ports.

Beware #1 !! All the example files are written for interactive use.  For batch use, add a blank line and then a term to be run.
Beware #2 !! The files in `example files` are in DOS text format.
For use on UNIX-type systems, including macOS, use `example_files_unix`.


## 3) Compile and run shell script
There is also a bash script, flin.sh, which takes flags and a text file, runs FLIN in batch mode and pipes output into INPLA for execution.
It assumes the two executables are in the same directory.
To make it executable, run command 
 chmod +x flin.sh
and then run it as ./flin.sh [flags] filename.txt.


## 4) Flags
The following flags can be used in both modes:
- -imm: implicit memory management; described in Section 4.2, below.
- -hof: higher order functions; see described in Section 4.3, below.

Flags can be given in any order and multiple flags can be used at once.

The following sections describe how the flags work and give the files that demonstrate them.


### 4.1) Base FLIN
Base FLIN is the compilation method if run without any flags.

Allows user-defined functions and constructors to be used according to the syntactic restrictions of function-constructor nets, that is the LHS is made up of a function applied to a constructor where each variable (port) occurs once and the RHS is a function-constructor net in which each variable (port) occurs once.
In addition generic constructors (Section 5.1 of submission) and integers (Section 5.3) can be used.

Integer variables must be noted with a leading underscore, for example:

```text
 add(0,  n) = n
 add(_m,_n) = succ(add(pred(m),n))
```
Note that, due to INPLA's requirements, the `n` in the base case must not be flagged as a number and neither `m` nor `n` should be flagged on the RHS.
FLIN will still compile if this is done, but the result will be either semantically or syntactically incorrect INPLA rules.

INPLA treats integers as an agent without a label with an "attribute" (see citation in paper, Section 5.3) which is the number.  The translation of rules with natural numbers therefore looks very different from others, as they are of the form:
```text
 foo(r,<vars>)><(int x) | x==n_0 => ... | x==n_1 => ... | ... | x==n_m => ... | _ => ...
```
with one `n_i` for each rule involving a specific value of `x`.
If there is not a rule covering the general case of `x` (i.e. `x` a variable) then, as per INPLA syntax, there needs to be the final, catch-all case (`_`), this is set to `_ => r~ERROR`.

Example files using only base FLIN:
- unary_arithmetic.txt
- nat_arithmetic.txt
- list.txt
- generics.txt


### 4.2) Implicit memory management
If the `-imm` flag is included, FLIN will add INPLA's in-built Eraser and Dupl agents as necessary.
Note that these are capitalised so do not follow our lower-case for functions syntax.

If a file that requires -imm is compiled without it, it may still generate a result but INPLA will refuse to execute those rules.

Example files using implicit memory management:
- fact.txt
- fib.txt
- imm.txt

This is described in Section 5.3 of the submission.


### 4.3) Higher-order functions
The `-hof` flag tells FLIN that one or more rules uses higher-order functions.
These are then translated into INPLA rules utilising the special higher order constructor `i_lam`, which represents the lambda constructor described in Section 5.4 of the submission.
Similarly, terms using higher-order functions will be modified to nets including `i_app`, which represents the application (@) function in the submission.

Example files using higher-order functions:
- hofs.txt


## 5) Some notes on FLIN
This is a demonstration of the viability of the approach, not a industry-ready compiler!
In particular, not all errors are caught and those that are have messages designed for the author not the user.

For example, swapping the first two lines of the example `even` and `odd` function definitions in Section 1, above, gives the mixture of internal and Haskell error messages:
```text
    flin: funcNumOuts reaches end of LUT for odd
    CallStack (from HasCallStack):
        error, called at .\Trans.hs:308:25 in main:Trans
```
FLIN does not check that the output is valid INPLA; that job is left to INPLA.
So, for example, terms which use variables multiple times without explicity duplicating or without the `-imm` flag will compile, but the resulting INPLA term will fail to execute.

**Beware!!** (Again!) All the example files are written for interactive use.  For batch use, add a blank line and then a term to be compiled.


## 6) Some notes on INPLA
Since FLIN requires INPLA to evaluate nets, it must be noted that the INPLA system itself is not a v1.0 either and may not always execute as expected.
Exiting and re-starting fixes a lot of problems...

Non-terminating nets will run on INPLA but will not show any output unless the `-w` flag is enabled.
See the INPLA documentation, section "Weak reduction strategy", for more information.
An example function which produces a stream output is fibS in fib.txt.

To use multi-threaded execution, INPLA must be compiled using the command `make clean; make thread` and then run with the `-t` option, followed by `1` to `8`, which sets the number of threads.
