# Building and running

You can run JONASFORTH inside QEMU or on real hardware. If you want to run
inside QEMU, you should have the following dependencies installed (assuming
Arch Linux):

    $ pacman -S qemu ovmf

Then, to run a UEFI shell inside QEMU, run:

    $ make qemu

JONASFORTH will be available as `main` on `FS0:`. Thus, to run it, you can run
the following command inside the UEFI shell:

    Shell> fs0:main
    Ready.
    S" Hello, World!" TELL
    Hello World!

(Try typing in the code in `example.f` for something a little more
interesting.)

## Running on real hardware

* [ ] This is not supported yet

# Notes on implementation

The implementation is based on
[JONESFORTH](https://raw.githubusercontent.com/nornagon/jonesforth/master/jonesforth.S).
This is my summary of the most important parts.

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

UEFI expects a UEFI application to be stored in a FAT32 file system on a
GPT-partitioned disk.

Luckily, QEMU has a convenient way of making a subdirectory availabe as a
FAT-formatted disk (see [the relevant section in the QEMU User
Documentation](https://qemu.weilnetz.de/doc/qemu-doc.html#disk_005fimages_005ffat_005fimages)
for more information):

    $ qemu-sytem-x86_64 ... -hda fat:/some/directory

We use this to easily test the image in QEMU; see the Makefile for more
information, or just run the `qemu` target to run the program inside of QEMU
(of course, you must have QEMU installed for this to work):

    $ make qemu

* [ ] How to build the image for real hardware (what should the image look like,
  which programs, commands, etc.)

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

A UEFI images is basically a windows EXE without symbol tables. There are three
types of UEFI images; we use the EFI application, which has subsystem `10`. It
is an x68-64 image, which has value `0x8664`.

UEFI applications use [Microsoft's 64-bit calling
convention](https://en.wikipedia.org/wiki/X86_calling_conventions#Microsoft_x64_calling_convention)
for x68-64 functions. See the linked article for a full description. Here is
the short version:

* Integer or pointer arguments are given in RCX, RDX, R8 and R9.
* Additional arguments are pushed onto the stack from right to left.
* Integer or pointer values are returned in RAX.
* An integer-sized struct is passed directly; non-integer-sized structs are passed as pointers.
* The caller must allocate 32 bytes of "shadow space" on the stack immediately
  before calling the function, regardless of the number of parameters used, and
  the caller is responsible for popping the stack afterwards.
* The following registers are volatile (caller-saved): RAX, RCX, RDX, R8, R9, R10, R11
* The following registers are nonvolatile (callee-saved): RBX, RBP, RDI, RSI, RSP, R12, R13, R14, R15

When the application is loaded, RCX contains a firmware allocated `EFI_HANDLE`
for the UEFI image, RDX contains a `EFI_SYSTEM_TABLE*` pointer to the EFI system
table and RSP contains the return address. For more infromation about how a UEFI
application is entered, see "4 - EFI System Table" in [the latest UEFI
specification as of March 2020 (PDF)](https://uefi.org/sites/default/files/resources/UEFI_Spec_2_8_A_Feb14.pdf).

**Sources:**

* [UEFI applications in detail - OSDev Wiki](https://wiki.osdev.org/UEFI#UEFI_applications_in_detail)
* [Microsoft x64 calling convention](https://en.wikipedia.org/wiki/X86_calling_conventions#Microsoft_x64_calling_convention)
* [UEFI Specifications](https://uefi.org/specifications)

### UEFI with FASM

We might want to consider using something like this: https://wiki.osdev.org/Uefi.inc)

FASM can generate UEFI application binaries by default. Use the following
template to output a 64-bit UEFI application:

    format pe64 dll efi
    entry main

    section '.text' code executable readable

    main:
       ;; ...
       ret

    section '.data' data readable writable

    ;; ...

Use `objdump -x` to inspect the assembled application binary.

### UEFI documentation

* [Latest specification as of March 2020 (PDF)](https://uefi.org/sites/default/files/resources/UEFI_Spec_2_8_A_Feb14.pdf)

Notable sections:

* 2\. Overview (14)
* 4\. EFI System Table (89)
* 7\. Services - Boot Services (140)
* 8\. Services - Runtime Services (228)
* 12\. Protocols - Console Support (429)
* 13\. Protocols - Media Access (493)
* Appendix B - Console (2201)
* Appendix D - Status Codes (2211)

## Resources

* [UEFI - OSDev Wiki](https://wiki.osdev.org/UEFI)
* [Unified Extensible Firmware Interface (Wikipedia)](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface)
* [UEFI Specifications](https://uefi.org/specifications)
