        NAME    Emu87Init
        PAGE    60,132
;[]------------------------------------------------------------[]
;|      87INIT.ASM -- Emulator initialization                   |
;|                                                              |
;|      Turbo-C Run Time Library        version 2.0             |
;|                                                              |
;|      Copyright (c) 1987,1988 by Borland International Inc.   |
;|      All Rights Reserved.                                    |
;[]------------------------------------------------------------[]
.8086
.8087

        INCLUDE RULES.ASI

;       Segment and Group declarations

Header@

;       External References

ExtSym@         _8087, WORD, __CDECL__

EXTRN   FPE1st     : FAR
EXTRN   FPElast    : FAR
EXTRN   __turboCvt : ABS        ; To force the link of REALCVT for printf

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      General notes                                           |
;|      =============                                           |
;|                                                              |
;|      Emu087  is  designed  to  run  only  if  the numeric    |
;|      coprocessor  is present  on the  machine. Since  the    |
;|      FP87LIB  is linked  in when  the user  said that the    |
;|      iNDP87  is present  no test  is done  to verify this    |
;|      fact.                                                   |
;|      Since the fixup constants  which are declared public    |
;|      in  this module  are all  equal to  zero, in-line 87    |
;|      instructions  are generated  by the  linker when  it    |
;|      tries to resolve the fixups.                            |
;|                                                              |
;|      The non-converted  functions of the  ninth interrupt    |
;|      are transcendental  functions not directly  provided    |
;|      by the 8087. These  functions must be interpreted by    |
;|      a library  provided in Real-87, which  uses the 8087    |
;|      for computations.                                       |
;|                                                              |
;|      The  tenth   interrupt  is  used  for   a  NOP-FWAIT    |
;|      sequence. It is  patched the first time it  is used,    |
;|      like the other direct iNDP instructions.                |
;|                                                              |
;|      The  shortcut  vector  is  used  for instructions or    |
;|      sequences frequently  used by the compiler.  Some of    |
;|      them  are  equivalent  to  '87  instructions,  while    |
;|      others cannot be reduced  to a simple sequence. When    |
;|      the '87  is present the  direct equivalents will  be    |
;|      patched  with  in-line  code,  while  the  composite    |
;|      sequences are executed in the interrupt routine.        |
;|                                                              |
;[]------------------------------------------------------------[]

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      FIXUP constants for Emu86                               |
;|                                                              |
;|      If  none  of  the  FI?RQQ  publics are used, then no    |
;|      floating point code will be linked in                   |
;|                                                              |
;[]------------------------------------------------------------[]

emInt           equ     34h     ; allocated to 8087 by Microsoft Corp.
shortcutInt     equ     3Eh     ; *** value for test usage ***

        PUBLIC  FIDRQQ          ; wait, esc
FIDRQQ  equ     00000h

        PUBLIC  FIARQQ          ; wait, DS:
FIARQQ  equ     00000h
        PUBLIC  FICRQQ          ; wait, CS:
FICRQQ  equ     00000h
        PUBLIC  FIERQQ          ; wait, ES:
FIERQQ  equ     00000h
        PUBLIC  FISRQQ          ; wait, SS:
FISRQQ  equ     00000h

        PUBLIC  FIWRQQ          ; nop, wait
FIWRQQ  equ     00000h

        PUBLIC  FJARQQ          ; Esc nn -> DS:nn
FJARQQ  equ     00000h
        PUBLIC  FJCRQQ          ; Esc nn -> CS:nn
FJCRQQ  equ     00000h
        PUBLIC  FJSRQQ          ; Esc nn -> ES:nn
FJSRQQ  equ     00000h

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      Emulator entry points                                   |
;|                                                              |
;[]------------------------------------------------------------[]

; This is the segment containing the code to work with the 8087 chip.

E87Seg@
EXTRN   e087_Entry      : FAR
EXTRN   e087_Shortcut   : FAR

;  These two public symbols are needed for __FPExcep module

        PUBLIC  emws_status
emws_status     dw      ?
        PUBLIC  emws_control
emws_control    dw      ?
E87SegEnd@

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      __emu1st -- Emulator installation routine               |
;|                                                              |
;|      This  function  is  called  by  RTLstart  before any    |
;|      numeric work  begins. It needs  to save the  initial    |
;|      interrupt vectors  before it can install  itself.       |
;|                                                              |
;|      The   __EMURESET   function  installs  the interrupt    |
;|      vectors   and   re-initializes  the  emulator.  This    |
;|      function is called by the _fpreset() function of the    |
;|      RTL.                                                    |
;|                                                              |
;[]------------------------------------------------------------[]

CSeg@

originalVectors dd      11 DUP (?)

_emu1st         PROC    FAR             ; called only by RTLstart
                push    di
                push    ES

; Install __FPExcep interrupt vector for 287 exceptions

                call    FPE1st

; Remember earlier use of vector. They must be replaced when
;       the program terminates.

                mov     ax,(35h * 256) + emInt
                mov     cx, 10          ; there are 10 emulation vectors
                mov     di, offset originalVectors
rememberLoop    label   near
                int     21h             ; ES:BX = read interrupt vector
                mov     cs:[di].w0, bx
                mov     cs:[di].w1, ES
                add     di, 4
                inc     ax
                loop    rememberLoop

; Now capture the Shortcut vector as well.

                mov     ax,(35h * 256) + shortcutInt
                int     21h             ; ES:BX = read interrupt vector
                mov     cs:[di].w0, bx
                mov     cs:[di].w1, ES
                pop     ES
                pop     di
                mov     __8087, 1       ; Assume 80?87 present

        PUBLIC  __EMURESET
__EMURESET      PROC    FAR
                push    DS
                push    bp
                mov     bp, sp
                sub     sp, 2

                mov     ax,(25h * 256) + emInt
                mov     cx, 10          ; there are 10 emulation vectors
                mov     dx, seg e087_Entry
                mov     ds, dx
                mov     dx, offset e087_Entry
captureLoop     label   near
                int     21h             ; Set interrupt vector with DS:DX
                inc     ax
                loop    captureLoop

; The Shortcut vector must be captured too.

                mov     ax,(25h * 256) + shortcutInt
                mov     dx, seg e087_Shortcut
                mov     ds, dx
                mov     dx, offset e087_Shortcut
                int     21h             ; Set interrupt vector with DS:DX

; 87 guaranteed
    FNINIT

; FINIT will disable all exception interrupts.  We want most enabled.

                mov     word ptr [bp-2], CW_DEFAULT
                Int     emInt + 1
                db      6Eh, 0FEh       ; (Wait, FLDCW  [bp-2]) equivalent

                mov     sp,bp
                pop     bp
                pop     DS
                ret
__EMURESET      ENDP
_emu1st         ENDP

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      __emuLast -- Emulator termination routine               |
;|                                                              |
;|      __emuLast  is called  by RTLstart  after the  "main"    |
;|      routine returns or the program exits. Its purpose is    |
;|      to  restore the  original contents  of the interrupt    |
;|      vectors 34h..3Dh, plus the Shortcut vector.             |
;|                                                              |
;[]------------------------------------------------------------[]

_emuLast        PROC    FAR     ; called only by RTLstart,

; Restore __FPExcep interrupt vector used for 287 exceptions

                call    FPElast

                push    DS
                mov     ax,(25h * 256) + emInt
                mov     bx,offset originalVectors
                mov     cx, 10          ; there are 10 emulation vectors
restoreLoop     label   near
                lds     dx,cs:[bx]
                int     21h             ; Set interrupt vector with DS:DX
                add     bx,4
                inc     ax
                loop    restoreLoop

; The Shortcut vector must be restored also.

                mov     ax,(25h * 256) + shortcutInt
                lds     dx,cs:[bx]
                int     21h             ; Set interrupt vector with DS:DX
                pop     DS
                ret
_emuLast        ENDP

CSegEnd@

        PAGE
;[]------------------------------------------------------------[]
;|                                                              |
;|      Emulator initialization and termination vectors         |
;|                                                              |
;[]------------------------------------------------------------[]

_EMUSEG SEGMENT WORD COMMON 'DATA'
__emu1st        dw      _emu1st
__emuLast       dw      _emuLast
_EMUSEG ENDS

END
