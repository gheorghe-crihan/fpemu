# Pretend-to-be Makefile for the Borland floating point emulator.

#all: wf87.obj em86.obj em87.obj
all: wf87.obj

wf87.obj: e87trans.asm rules.asi
	TASM /o wf87.obj e87trans.asm rules.asi

# The biggest target, contains the bulk of the code.
# Most of it not provided, however.
em86.obj: emu086.asm rules.asi e286defs.asi emuvars.asi \
          emumoves.asm ieeemove.asm emuarith.asm emuarith.doc \
          emutrans.asm emutrans.doc e086tran.asm emhort.asm \
          emudecim.asm opdecode.asm
	TASM /o em86.obj ...

# Smaller chunk, looks like some add-on/overlay for 80387
# Still, most of the source code is not provided.
em87.obj: emu087.asm rules.asi e287defs.asi emuvars.asi \
          e087tran.asm e087entr.asm
	TASM /o em87.obj ...
 