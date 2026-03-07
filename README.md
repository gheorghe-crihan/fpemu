# Borland C Floating Point Emulator Source Code

I have been desperately hunting for Borland's floating point
emulator source code for many years now, not least owing to
being fascinated during my youth by the FPU chip itself (that
is, floating point calculations in hardware, driven by software
instructions) and even more so by its dynamic (via illegal
instruction exception of 80286/80386) or static (via software
library calls, patched-in by the compiler, given appropriate
switch, through specific INT instructions) emulation purely in
software.

Now that Borland's (aka Inprise's, aka Embarcadero's) compilers
are legacy, formerly given away for free (by Inprise on their
website) for non-commercial (hobbyist) use, hence are basically
dead (abandonware).

That said, there could be academic and research benefit from
summarizing the relevant information, so I dare to present the
scarce source code still available, as well as some third-party
research notes.

It is important to note that the source code is still under
Borland's copyright so should be property of its legal successors. 

It looks like there's no sense in searching for the missing
bits online or on e-bay (although most of the rest of Runtime
Library source code *is* indeed available for both, Pascal and
C/C++) as the below excerpt from the CRTL.DOC
mentiones explicitly that the source code for the floating point
emulator is *NOT* offered:

| Borland International, Inc. (Borland) is offering you a license
| to the source code to the Borland C++ Runtime Library portion of
| Borland C++ (the Source Programs), including updates that may
| later be supplied by Borland at additional cost, *but not
| including the source code of the 8087 emulator* or the graphics
| library.

## Third-party notes


## Other vendors

OpenWatcom v2 source code contains the 8087 emulator source under
https://github.com/open-watcom/open-watcom-v2/blob/master/bld/fpuemu/i86/asm/emu8087.asm

Intel did have some 8087 support library providing full FPU
emulation (should be the most precise on the planet, given
the need for internal QA and production tooling at Intel when
manufacturing 8087) that was shipped as part of some Intel
assembler and surfaced as em87 emulator on Simtelnet by someone,
that when unpacked, produces Intel's copyright string.
