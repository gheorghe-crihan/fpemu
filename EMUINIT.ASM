  NAME  EmuInit
  PAGE  60,132
;[]------------------------------------------------------------[]
;|      EMUINIT.ASM -- Emulator initialization                  |
;|                                                              |
;|      Turbo-C Run Time Library version 2.0                    |
;|                                                              |
;|      Copyright (c) 1987,1988 by Borland International Inc.   |
;|      All Rights Reserved.                                    |
;[]------------------------------------------------------------[]
.8086
.8087

  INCLUDE RULES.ASI

; Segment and Group declarations

Header@

; External References

ExtSym@ _8087, WORD, __CDECL__

EXTRN FPE1st     : FAR
EXTRN FPElast    : FAR
EXTRN __turboCvt : ABS  ; To force the link of REALCVT for printf

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      General notes                                           |
;|      =============                                           |
;|                                                              |
;|      Emu086 is  designed to run  in either of  two modes:    |
;|      with   or   without   the   presence   of  the  8087    |
;|      co-processor. The  first action it takes  is to test    |
;|      for the presence of the co-processor.  Depending  on    |
;|      which it  finds, it connects  one of two  modules to    |
;|      the   interrupt   vectors   reserved   for   numeric    |
;|      coprocessor emulation.                                  |
;|                                                              |
;|      E087ENTR.ASM ("Real-87")                                |
;|                                                              |
;|      This module  is to be  used when there  is  hardware    |
;|      support.  It  is  a  much   smaller   module.   This    |
;|      module  will  service  10  interrupt  vectors   (34h    |
;|      through 3Dh)  which  are  used  for  floating  point    |
;|      invocation by application  programs.  For  the first    |
;|      eight of the vectors  plus  some  functions  of  the    |
;|      ninth, Real-87 will patch  the calling program  with    |
;|      the equivalent 8087  instruction  sequence  and then    |
;|      restart  the  program  to   run   the   patch.   The    |
;|      application will thus be converted at  run  time  to    |
;|      the use of the co-processor.                            |
;|                                                              |
;|      The non-converted  functions of the  ninth interrupt    |
;|      are transcendental  functions not directly  provided    |
;|      by the 8087. These  functions must be interpreted by    |
;|      a library  provided in Real-87, which  uses the 8087    |
;|      for computations.                                       |
;|                                                              |
;|      The   tenth   interrupt  is  used  for  a  NOP-FWAIT    |
;|      sequence.  It is patched the first time it  is used,    |
;|      like the other direct iNDP instructions.                |
;|                                                              |
;|      The  shortcut  vector  is  used for instructions  or    |
;|      sequences frequently  used by the compiler.  Some of    |
;|      them  are  equivalent  to  '87  instructions,  while    |
;|      others cannot be reduced  to a simple sequence. When    |
;|      the '87 is present the direct  equivalents  will  be    |
;|      patched  with  in-line  code,  while  the  composite    |
;|      sequences are eexcuted in the interrupt routine.        |
;|                                                              |
;|      E086ENTR.ASM ("Virtual-87")                             |
;|                                                              |
;|      The Virtual-87 module is to be used when the 8087 is    |
;|      not  present.  It  supplies  all  code necessary  to    |
;|      emulate the  8087 (excepting some rare details.  See    |
;|      the    description   in   the   general  notes   for    |
;|      e086Entr.asm).  No  patching  occurs  in  this case,    |
;|      except for the tenth  interrupt which can be patched    |
;|      to a No-op sequence.                                    |
;|                                                              |
;[]------------------------------------------------------------[]

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      FIXUP constants for Emu86                               |
;|                                                              |
;|      If none of the FI?RQQ publics are used, then no         |
;|      floating point code will be linked in.                  |
;|                                                              |
;[]------------------------------------------------------------[]

emInt equ 34h ; allocated to 8087 by Microsoft Corp.
shortcutInt equ 3Eh ; *** value for test usage ***


  PUBLIC  FIDRQQ  ; wait, esc
FIDRQQ equ 05C32h

  PUBLIC  FIARQQ  ; wait, DS:
FIARQQ equ 0FE32h
  PUBLIC  FICRQQ  ; wait, CS:
FICRQQ equ 00E32h
  PUBLIC  FIERQQ  ; wait, ES:
FIERQQ equ 01632h
  PUBLIC  FISRQQ  ; wait, SS:
FISRQQ equ 00632h

  PUBLIC  FIWRQQ  ; nop, wait
FIWRQQ equ 0A23Dh

  PUBLIC  FJARQQ  ; Esc nn -> DS:nn
FJARQQ equ 04000h
  PUBLIC  FJCRQQ  ; Esc nn -> CS:nn
FJCRQQ equ 0C000h
  PUBLIC  FJSRQQ  ; Esc nn -> ES:nn
FJSRQQ equ 08000h

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      Emulator entry points                                   |
;|                                                              |
;[]------------------------------------------------------------[]

; This is the segment containing the full emulation code.

EmuSeg@
EXTRN e086_Entry : FAR
EXTRN e086_Shortcut : FAR
EmuSegEnd@

; This is the segment containing the code to work with the 8087 chip.

E87Seg@
EXTRN e087_Entry : FAR
EXTRN e087_Shortcut : FAR
E87SegEnd@

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      __emuTest -- Co-processor autosense routine             |
;|                                                              |
;|      Note: The code used to test the presence of a           |
;|      numeric coprocessor is recommended by IBM.              |
;|                                                              |
;[]------------------------------------------------------------[]

CSeg@
__emuTest PROC  NEAR
    push bp
    mov bp, sp
    sub sp, 2

; If  CPU is  an 80286, the FNINIT  instruction can  generate an
; interrupt  if  the  NDP?87  is not  present.  On IBM systems, an
; interrupt handler is provided by  the BIOS but it may NOT be
; provided on clones. So don't test if there is or not an NDP?87, we
; will just trust the BIOS equipment flag.

    push sp
    pop ax
    cmp ax, sp
    jne TestPresence

; The CPU is an 80286 so trust the BIOS equipment flag.

    int 11h
    and ax, 2
    jnz __emuTest0
    jmp short __emuTest1

; First check to see if a real 8087/287 is available. That allows
; us to  select which version  of NDP support  is to remain
; resident.

TestPresence label near
;   xor ax, ax
;   out 0F0h, al  ; Clear the busy latch (INT REQ)

    FNINIT

    mov word ptr [bp-2], 0
    FNSTCW word ptr [bp-2] ; Store the control word
    mov cx, 20
    loop this near  ; Delay awhile
    mov ax, [bp-2]  ; Get NPX control word
    and ax, 0F3Fh ; Mask off undefined bits
    cmp ax, 033Fh ; Do we have a math coprocessor
    mov ax, 0
    jne __emuTest1 ; No ...

    mov word ptr [bp-2], -1
    FNSTSW word ptr [bp-2] ; Store the status word
    mov cx, 20
    loop this near ; Delay awhile
    test word ptr [bp-2], 0B8BFh ; All bits off that could be ?
    jnz __emuTest1
__emuTest0 label near
    mov ax, 1
__emuTest1 label near
    mov sp, bp
    pop bp
    ret
__emuTest ENDP

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      __emu1st -- Emulator installation routine               |
;|                                                              |
;|      This   function  is  called  by  RTLstart before any    |
;|      numeric work  begins. It needs to save  the  initial    |
;|      interrupt vectors  before  it  can  install  itself.    |
;|                                                              |
;|      It will sense whether an iNDP87 co-processor exists,    |
;|      only if the _8087 variable is set to -1, which means    |
;|      that no "87" environment  variable has been defined.    |
;|      In that case it will choose which of the two numeric    |
;|      support modules is to be kept. The interrupt vectors    |
;|      34..3D  are  claimed  for  iNDP  software  interrupt    |
;|      support.                                                |
;|                                                              |
;|      An  additional  interrupt,  3Eh,  is  used  for  the    |
;|      Shortcut entries.                                       |
;|                                                              |
;|      The  __EMURESET  function  installs  the   interrupt    |
;|      vectors   and   re-initializes  the  emulator.  This    |
;|      function is called by the _fpreset() function of the    |
;|      RTL.                                                    |
;|                                                              |
;[]------------------------------------------------------------[]

originalVectors dd 11 DUP (?)

_emu1st PROC FAR  ; called only by RTLstart
    push di
    push ES

; Install __FPExcep interrupt vector for 287 exceptions

    call FPE1st

; Remember earlier use of vector.  They must be replaced when the program
; terminates.

    mov ax, (35h * 256) + emInt
    mov cx, 10 ; there are 10 emulation vectors
    mov di, offset originalVectors
rememberLoop label near
    int 21h ; ES:BX = read interrupt vector
    mov cs:[di].w0, bx
    mov cs:[di].w1, ES
    add di, 4
    inc ax
    loop rememberLoop

; Now capture the Shortcut vector as well.

    mov ax, (35h * 256) + shortcutInt
    int 21h ; ES:BX = read interrupt vector
    mov cs:[di].w0, bx
    mov cs:[di].w1, ES
    pop ES
    pop di

; Do we need to test 80?87 presence ?
    cmp _8087@, -1
    jne __EMURESET
    call __emuTest
    mov _8087@, ax

    PUBLIC __EMURESET
__EMURESET PROC FAR
    FNINIT  ; reset first
    push DS
    push bp
    mov bp, sp
    sub sp, 8

    mov ax, seg _8087@
    mov ds, ax
    cmp _8087@, 0
    mov word ptr [bp-4], offset e087_Entry
    mov word ptr [bp-2], seg e087_Entry
    mov word ptr [bp-8], offset e087_Shortcut
    mov word ptr [bp-6], seg e087_Shortcut
    jne doCapture
    mov word ptr [bp-4], offset e086_Entry
    mov word ptr [bp-2], seg e086_Entry
    mov word ptr [bp-8], offset e086_Shortcut
    mov word ptr [bp-6], seg e086_Shortcut

; Now take over the vectors.

doCapture label near
    mov ax, (25h * 256) + emInt
    mov cx, 10  ; there are 10 emulation vectors
    lds dx, dword ptr [bp-4]
captureLoop label near
    int 21h ; Set interrupt vector with DS:DX
    inc ax
    loop captureLoop

; The Shortcut vector must be captured too.

    mov ax, (25h * 256) + shortcutInt
    lds dx, dword ptr [bp-8]
    int 21h ; Set interrupt vector with DS:DX

; Now emulation is installed. Ensure it is initialized. Note that
; these  codes must  be patched  in because  other parts of
; this  source  module  require  the  /R switch to disable
; emulation.

    Int emInt + 3
    db 0E3h ; (Wait, FINIT) equivalent

; FINIT will disable all exception interrupts.  We want most enabled.

    mov word ptr [bp-2], CW_DEFAULT
    Int emInt + 1
    db 6Eh, 0FEh  ; (Wait, FLDCW [bp-2]) equivalent

    mov sp,bp
    pop bp
    pop DS
    ret
__EMURESET ENDP
_emu1st ENDP

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|       __emuLast -- Emulator termination routine              |
;|                                                              |
;|      __emuLast  is called  by RTLstart  after the  "main"    |
;|      routine returns or the program exits. Its purpose is    |
;|      to  restore the original contents  of the  interrupt    |
;|      vectors 34h..3Dh, plus the Shortcut vector.             |
;|                                                              |
;[]------------------------------------------------------------[]

_emuLast PROC FAR ; called only by RTLstart,

; Restore __FPExcep interrupt vector used for 287 exceptions

    call FPElast

    push DS
    mov ax,(25h * 256) + emInt
    mov bx,offset originalVectors
    mov cx, 10  ; there are 10 emulation vectors
restoreLoop label near
    lds dx,cs:[bx]
    int 21h  ; Set interrupt vector with DS:DX
    add bx,4
    inc ax
    loop restoreLoop

; The Shortcut vector must be restored also.

    mov ax,(25h * 256) + shortcutInt
    lds dx,cs:[bx]
    int 21h  ; Set interrupt vector with DS:DX
    pop DS
    ret
_emuLast  ENDP

CSegEnd@

  PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      Emulator initialization and termination vectors         |
;|                                                              |
;[]------------------------------------------------------------[]

_EMUSEG SEGMENT WORD COMMON 'DATA'
  dw  _emu1st
  dw  _emuLast
_EMUSEG ENDS
  END
