# Building and running

Create the executable:

    $ make main

The `sys.f` file contains code that defines some of the usual words that you
would expect in a Forth distribution. To run this code and then read from
standard input, run:

    $ cat sys.f - | ./main

The `example.f` file contains an example that you can run with:

    $ cat sys.f example.f | ./main

## Running with UEFI

We are currently in the process of implementing support for running without
Linux, by instead relying on UEFI. Eventually, this will be the only supported
method of running the interpreter, but currently the UEFI-related code is
isolated in the `uefi/` directory and does not yet contain an implementation of
the main program.

You should have the following dependencies installed (assuming Arch Linux):

    $ pacman -S qemu ovmf

To run a UEFI shell inside qemu, cd to `uefi/` and run:

    $ make run

# Notes on implementation

This is my summary of the most important parts of
https://raw.githubusercontent.com/nornagon/jonesforth/master/jonesforth.S.

## Dictionary

In Forth, words are stored in a dictionary. The dictionary is a linked list
whose entries look like this:

    +------------------------+--------+---------- - - - - +----------- - - - -
    | LINK POINTER           | LENGTH/| NAME              | DEFINITION
    |                        | FLAGS  |                   |
    +--- (4 bytes) ----------+- byte -+- n bytes  - - - - +----------- - - - -

For example, DOUBLE and QUADRUPLE may be stored like this:

      pointer to previous word
       ^
       |
    +--|------+---+---+---+---+---+---+---+---+------------- - - - -
    | LINK    | 6 | D | O | U | B | L | E | 0 | (definition ...)
    +---------+---+---+---+---+---+---+---+---+------------- - - - -
       ^       len                         padding
       |
    +--|------+---+---+---+---+---+---+---+---+---+---+---+---+------------- - - - -
    | LINK    | 9 | Q | U | A | D | R | U | P | L | E | 0 | 0 | (definition ...)
    +---------+---+---+---+---+---+---+---+---+---+---+---+---+------------- - - - -
       ^       len                                     padding
       |
       |
    LATEST

The Forth variable LATEST contains a pointer to the most recently defined word.

## Threaded code

In a typical Forth interpreter, code is stored in a peculiar way. (This way of
storing code is primarily motivated by space contraints on early systems.)

The definition of a word is stored as a sequence of memory adresses of each of
the words making up that definition. (At the end of a compiled definition, there
is also some extra code that causes execution to continue in the correct way.)

We use a register (ESI) to store a reference to the next index of the
word (inside a definition) that we are executing. Then, in order to execute a
word, we just jump to whatever address is pointed to by ESI. The code for
updating ESI and continuing execution is stored at the end of each subroutine.

Of course, this approach only works if each of the words that we are executing
is defined in assembly, but we also want to be able to execute Forth words!

We get around this problem by adding a "codeword" to the beginning of any
compiled subroutine. This codeword is a pointer to the intrepreter to run the
given function. In order to run such functions, we actually need two jumps when
executing: In order to execute a word, we jump to the address at the location
pointed to by the address in ESI.

## Definitions

What does the codeword of a Forth word contain? It needs to save the old value
of ESI (so that we can resume execution of whatever outer definition we are
executing at the time) and set the new version of ESI to point to the first word
in the inner definition.

The stack where the values of ESI are stored is called the "return stack". We
will use EBP for the return stack.

As mentioned, whenever we finish executing a Forth word, we will need to
continue execution in the manner described in the previous section. When the
word being executed is itself written in Forth, we need to pop the old value of
ESI that we saved at the beginning of the definition before doing this.

Thus, the actual data for a word in a dictionary will look something like this:

      pointer to previous word
       ^
       |
    +--|------+---+---+---+---+---+---+---+---+------------+------------+------------+------------+
    | LINK    | 6 | D | O | U | B | L | E | 0 | DOCOL      | DUP        | +          | EXIT       |
    +---------+---+---+---+---+---+---+---+---+------------+--|---------+------------+------------+
       ^       len                         pad  codeword      |
       |                                                      V
      LINK in next word                            points to codeword of DUP

Here, DOCOL (the codeword) is address of the simple interpreter described above,
while EXIT a word (implemented in assembly) that takes care of popping ESI and
continuing execution. Note that DOCOL, DUP, + and EXIT are all stored as
addresses which point to codewords.

## Literals

Literals are handled in a special way. There is a word in Forth, called LIT,
implemented in assembly. When executed, this word looks at the next Forth
instruction (i.e. the value of ESI), and places that on the stack as a literal,
and then manipulates ESI to skip over the literal value.

## Built-in variables

* **STATE** -- Is the interpreter executing code (0) or compiling a word (non-zero)?
* **LATEST** -- Points to the latest (most recently defined) word in the dictionary.
* **HERE** -- Points to the next free byte of memory.  When compiling, compiled words go here.
* **S0** -- Stores the address of the top of the parameter stack.
* **BASE** -- The current base for printing and reading numbers.

## Input and lookup

`WORD` reads a word from standard input and pushes a string (in the form of an
address followed by the length of the string) to the stack. (It uses an internal
buffer that is overwritten each time it is called.)

`FIND` takes a word as parsed by `WORD` and looks it up in the dictionary. It
returns the address of the dictionary header of that word if it is found.
Otherwise, it returns 0.

`>CFA` turns a dictionary pointer into a codeword pointer. This is used when
compiling.

## Compilation

The Forth word INTERPRET runs in a loop, reading in words (with WORD), looking
them up (with FIND), turning them into codeword pointers (with >CFA) and then
deciding what to do with them.

In immediate mode (when STATE is zero), the word is simply executed immediately.

In compilation mode, INTERPRET appends the codeword pointer to user memory
(which is at HERE). However, if a word has the immediate flag set, then it is
run immediately, even in compile mode.

### Definition of `:` and `;`

The word `:` starts by reading in the new word. Then it creates a new entry for
that word in the dictoinary, updating the contents of `LATEST`, to which it
appends the word `DOCOL`. Then, it switches to compile mode.

The word `;` simply appends `EXIT` to the currently compiling definition and
then switches back to immediate mode.

These words rely on `,` to append words to the currently compiling definition.
This word simply appends some literal value to `HERE` and moves the `HERE`
pointer forward.

# Notes on UEFI

`JONASFORTH` is runs without an operating system, instead using the facilities
provided by UEFI by running as a UEFI application. (Or rather, in the future it
hopefully will. Right now, it uses Linux.) This section contains some notes
about how this functionality is implemented.

## Packaging and testing the image

* [ ] What should the image look like?
* [ ] How to build the image (which programs, commands, etc.)
* [ ] How do we run the application in QEMU

## Interfacing with UEFI

From [OSDev Wiki](https://wiki.osdev.org/UEFI#How_to_use_UEFI):

>Traditional operating systems like Windows and Linux have an existing software
>architecture and a large code base to perform system configuration and device
>discovery. With their sophisticated layers of abstraction they don't directly
>benefit from UEFI. As a result, their UEFI bootloaders do little but prepare
>the environment for them to run.
>
>An independent developer may find more value in using UEFI to write
>feature-full UEFI applications, rather than viewing UEFI as a temporary
>start-up environment to be jettisoned during the boot process. Unlike legacy
>bootloaders, which typically interact with BIOS only enough to bring up the OS,
>a UEFI application can implement sophisticated behavior with the help of UEFI.
>In other words, an independent developer shouldn't be in a rush to leave
>"UEFI-land".

For `JONASFORTH`, I have decided to run as a UEFI application, taking advantage
of UEFI's features, including its text I/O features and general graphical device
drivers. Eventually, we would like to add some basic graphical drawing
capabilities to `JONASFORTH`, and it's my impression that this would be possible
using what is provided to us by UEFI.

* [ ] How to register as a UEFI application
* [ ] How to use UEFI provided functions

## Resources

* https://wiki.osdev.org/UEFI
* https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface
