




This UIC contains the source, object modules, and task images for a game
similar to the popular arcade game, PACMAN.  To play you need:

	1 PDP-11 (or VAX-see below) computer running RSX-11M or RSX-11M+
	1 VT100 terminal at 9600 baud (Advanced Video Option NOT required)

A brief set of playing instructions are present in the file PACMAN.DOC.

Two versions of the task are provided, PACFSL.TSK for those of you who have
a supervisor mode FCS library, and PAC.TSK for everybody else. The supervisor
mode library version runs in about 13K words of memory, and the regular
version in about 16K words. This program has been run in both a PDP 11/44 and
a PDP 11/23 successfully, although it is a bit too slow in the 11/23.
(The PAC.TSK version has also been run successfully in compatibility mode
on a VAX 11/750, although brief inspection indicates that the control-C
AST and the mark time directive in the main program loop do not seem to work.
Neither of these problems seriously affects the useability of the program.)

Task build command files are provided for both versions:
  (PACFSL.TKB and PAC.TKB)

The source code is written mostly in RATFOR, with some assembly language.
A command file to assemble and compile the source is provided (PACMAN.BLD)

The attempt has been made to give this game as much of the "feel" of
PACMAN as possible.  Your comments, suggestions, complaints, praise, etc.
would be appreciated, in particular whether the game is too hard or easy.


					Glen Hoffing
					RCA Gov't Communications Systems
					Front and Cooper Sts.  10-4-6
					Camden, NJ 08102
