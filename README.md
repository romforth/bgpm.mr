# A reimplementation of Martin Richards' BGPM converted from BCPL to Odin (and C)

This is a "bug compatible" conversion into Odin of Martin Richards' BGPM
implementation in BCPL which is available at: https://github.com/8l/bgpm
The original code is in this file: bcplprogs/bgpm/bgpm.b of that repo

This is a followup to my previous GPM conversion (from Rust to C) which
is available at: https://github.com/romforth/gpm.psl

After wrapping that up, I then decided to use Martin Richards version when I
noticed that he had found and fixed a subtle bug in Strachey's version
(see the file bcplprogs/bgpm/bug.bgpm) which turned out to be hard to fix with
the single stack implementation. I also liked the symmetry between Richards'
two stack implementation and the data+return stacks of Forth.

I chose Odin since my idle browsing on Ginger Bill's blog at:
https://gingerbill.org/article/2021/12/15/multiple-return-values-research
mentioned that it supported multiple assignment which is used extensively in
the BCPL version of the code. The fact that bootstrapping Odin was easy (since
it is just a `make` away) was just icing on the cake.

Just like in the Rust to C conversion that I used in the earlier project, I
used a helper Perl script called convert (which is part of this repo) until
the errors from the Odin compiler dropped below ~100 lines and then resorted
to manually fixing up the rest of the code which could not be handled by easy
regexp replacements. The major places where I had to manually intervene was
in the handling of loops since BCPL has REPEAT/REPEATUNTIL/REPEATWHILE/UNTIL
in addition to the C like FOR/WHILE whereas Odin has just one loop construct:
'for' and nothing else. I liked that bit of minimalism but I didn't like the
fact that Odin also doesn't have gotos so I had to do a bit of code shuffling
and get into some contortions to have things working as expected. On the more
positive side, I liked the fact that the definitions could be anywhere - unlike
C, which needs forward declarations - an issue that I kept running into in the
previous GPM porting project. Another difference from C was that parameters are
not writable so I needed to throw in a few additional variables for a bunch of
routines to shadow the inputs.

I actually wondered if it would be more fun to write a BCPL codegen that spit
out Odin code but I didn't want to bother with the grunt work involved.

I tried to match the original BCPL code as exactly as possible - even trying
to keep the number of lines identical wherever I could.

As with the earlier GPM implementations, I've taken the liberty of changing
the syntax of the GPM language to match the one that I had used earlier in:
https://github.com/romforth/gpm (and in https://github.com/romforth/gpm.psl).
I did this primarily for the sake of consistency - so that I can use the tests
from the older GPM ports as is.

Once the Odin port was completed and seen to be working well, I decided to port
_that_ to C since it seemed to be a fairly trivial/easy exercise. The one change
between the two implementations is in the handling of EOF since I was on terra
firma with C whereas I was using Odin for the very first time in this project.
