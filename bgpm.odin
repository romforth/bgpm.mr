/*
 * An Odin implementation of Martin Richards BGPM (BCPL? General Purpose
 * Macrogenerator) converted from the BCPL version at:
 * 	https://github.com/8l/bcpl file: bcplprogs/bgpm/bgpm.b
 * which in turn was based on (and the bugs fixed up from) the CPL
 * version in Christopher J. Strachey's '65 GPM paper.
 *
 * The BCPL to Odin conversion was mostly done using a brute force line level
 * "translator" written in Perl which worked for the majority of the code
 * with the rest of the heavy lifting done manually.
 *
 * Copyright (c) 2026 Charles E. Suresh, Martin Richards
 *
 * Licence: AGPLv3
 * SPDX-License-Identifier: AGPL-3.0-only
 * Please see the LICENSE file for the Affero GPL 3.0 license details
 */


package bgpm

import "core:fmt"
import "core:os"
import "core:c/libc"

// GLOBAL {

s, h, f, t, p, e, c: int
ch: int
sysin, sysout, fromstream, tostream: ^os.File
base: []int
upb: int
chpos: int
tracing: bool

// GLOBAL }

// MANIFEST {

s_eof		:: -1
s_eom		:: -2
s_def		:: -3
s_set		:: -4
s_eval		:: -5
s_lquote	:: -6
s_rquote	:: -7

c_call		:: int('[')
c_apply		:: int(']')
c_sep		:: int('\\')
c_skip		:: int('~')
c_lquote	:: int('{')
c_rquote	:: int('}')
c_arg		:: int('^')

// MANIFEST }

// OS specific shim {

rdch :: proc() -> int {
	c := libc.getchar()
	if c == libc.EOF { return s_eof }

	return int(c)
}

wrch :: proc(c: i32) { libc.putchar(c) }

writes :: proc(s: string) { fmt.printf(s) }

writef :: proc(format: string, args: ..any) {
	s := fmt.aprintf(format, ..args); defer delete(s)
	fmt.println(s)
}

newline :: proc() { wrch('\n') }

// OS specific shim }

// rewrite start as main and move it to the end

putch :: proc(ch: int) { if h == 0 { wrch(i32(ch)) } else { push(ch) } }

push :: proc(ch: int) -> int {
	if t == s { error("Insufficient work space") }
	s += 1
	base[s] = ch
//fmt.println("set base[", s, "] to ", ch, "in push")
	return s
}

getch :: proc() -> int {
	ch: int
	if c != 0 { c += 1; return base[c] }

	ch = rdch()

	for ch == c_skip {
		// Ignore all character until the end of the line
		ch = rdch(); for ch != int('\n') && ch != int('\r') && ch != s_eof { ch = rdch() }
		// Now ignore all white space characters
		for ch == int('\n') || ch == int('\r') || ch == int(' ') || ch == int('\t') { ch = rdch() }
	}

	return ch
}

arg :: proc(ai: int, ni: int) -> int { a, n := ai, ni	// since ai and ni are not writable
//fmt.println("a: ", a, "n: ", n)
	for {
		if base[a] < 0 { error("Too few arguments") }
		if n == 0 { return a }
		a, n = a+base[a]+1, n-1
//fmt.println("new a: ", a, "n: ", n)
	}
}

lookup :: proc(a: int) -> int {
	q, i, len := e, 0, base[a]
	for q != 0 && i <= len {
//fmt.println("comparing base[",q+i+2,"] (=",base[q+i+2],") with base[",a+1,"] (=",base[a+i], ")")
		if base[q+i+2] == base[a+i] { i += 1 } else { q, i = base[q], 0 }
	}
	if q == 0 { error("Macro not defined") }
	return q
}

define :: proc(name: string, code: int) {
	// Define a builtin macro
	s1 := s
	push(e); push(t)
	push(len(name)); for c in name { push(int(c)) }
	push(1); push(code); push(s_eom)
	for s != s1 { base[t] = base[s]; t -= 1; s -= 1 }
	e = t+1
}

bgpm :: proc() {
	s, t, h, p, f, e, c = -1, upb-1, 0, 0, 0, 0, 0

	define("def",		s_def)
	define("set",		s_set)
	define("eval",		s_eval)
	define("lquote",	s_lquote)
	define("rquote",	s_rquote)
	define("eof",		s_eof)

	skip := false
	hack := true
	for {				// Start of main scanning loop.
		if (skip) { skip = false } else { ch = getch() }
		switch ch {
		case c_lquote:		// {
//writef("lquote\n")
			d := 1
			for {
				ch = getch()
				if ch == s_eof { skip = true; break }
				if ch < 0 { error("Non character in quoted string") }
				if ch == c_lquote { d += 1 }
				if ch == c_rquote { d -= 1; if d == 0 { break } }
				putch(ch)
			}
//writef("rquote\n")

		case c_call:		// [
//writef("Call\n")
			// NEW: save current e and t so that definitions created
			// by the call can be preserved while local definitions
			// are removed.  See s_eom.
			f = push(f); push(h); push(e); push(t)
			h = push(0)

		case c_sep:		// \
//writef("Sep\n")
			if h == 0 { putch(ch); continue }
			base[h] = s-h
//fmt.println("set base[", h, "] to ", s-h, "in c_sep")
			h = push(0)

		case c_arg:		// ^
//writef("Arg\n")
			if p == 0 { putch(ch); continue }
			ch = getch()
			a := arg(p+4, rdn())
			for q := a+1; q <= a+base[a]; q += 1 { putch(base[q]) }
			skip = true

		case c_apply:		// ]
//writef("Apply\n")
			a := f
			if h == 0 { putch(ch); continue }
//fmt.println("set base[", h, "] to ", s-h, " in apply")
			base[h] = s-h
			push(s_eom)
			f, h = base[a], base[a+1]	// Restore the previous f and h
			base[a], base[a+1] = p, c	// a!2, a!3 contain e, t when [ was encountered
			for s >= a { base[t] = base[s]; t -= 1; s -= 1 }
			p = t+1
			c = arg(lookup(p+4)+2, 1)

			if (tracing) {
				i := 0
				a := p+4  // Pointer to arg 0
				writef("\nCalling macro\n")
				for (base[a]>=0) {
					writef("arg %i2: ", i)
					//wrarg(a)
					newline()
					a := a + base[a] +1
					i := i+1
				}
//prstate()
			}
		case s_lquote: putch(c_lquote)
		case s_rquote: putch(c_rquote)

		case s_eof:	return

		// s_set and s_val have been moved here to get rid of the GOTO which Odin doesn't allow
		case s_set:
//writef("Set\n")
			name := arg(p+4, 1)
			val  := arg(p+4, 2)
			len := base[val]
			a := lookup(name)
			b := arg(a+2, 1)
			max := base[a+1] - b - 1	// Max length of the value.
			if len > max { error("New value too long") }
			for i := 0; i <= len; i += 1 { base[b+i] = base[val+i] }
			base[b+len+1] = s_eom
			// GOTO ret emulated by falling through, hack is to skip over s_eval
			hack = false
			fallthrough

		case s_eval:
//writef("Eval\n")
			// The hack flag is only to skip over s_eval - see above
			if (hack) {
				c = arg(p+4, 1)
				wrn(exp(0))
			} else {
				hack = true
			}
			// GOTO ret emulated by falling through
			fallthrough

		case s_eom:
//writef("Eom\n")
//ret:
			if p == 0 { continue }
			a := t
			q := p - 1
			n := base[p+3] - p + 1	// This is the distance that the new
						// definitions will be moved by, as
						// a result of removing the call and
						// local definitions.
			base[a] = e

			for {
				na := base[a]
				if na > p { break }
				// na points to a new definition
				base[a] = na + n	// Adjust this pointer
				a = na
			}

			base[a] = base[p+2]	// Unlink the local definitions from the chain, if any.
			e = base[t]		// Get the (possible) new e.

			a = t
			t = base[p+3]
			c = base[p+1]
			p = base[p]

			// Copy the new definitions, if any.
			for q > a {
				base[t] = base[q]; t -= 1; q -= 1
			}
//prstate()

		case s_def:
//writef("Def\n")
			a1 := arg(p+4, 1)
			a2 := arg(p+4, 2)
			ne := a1 - 2  // ne -> [e0, end, <name> <val> ]
			// Find end of definition
			q := p+4
			for base[q] >= 0 { q = q+base[q]+1 }
			// q points to the eom at the end of the call.
			// Put eom at end of second argument.
			base[a2+base[a2]+1] = s_eom
			base[ne], base[ne+1] = e, q
			e = ne
			c, t = base[p+1], e-1
			p = base[p]
//writef("def: e=%n ", e)
//item(a1)
//newline()

		case:
			putch(ch)
		}
	}
}

rdn :: proc() -> int {
	val := 0
	for int('0') <= ch && ch <= int('9') {
		val = 10*val + ch - int('0')
		ch = getch()
	}
	return val
}

bexp :: proc() -> int {
	ch = getch()
	switch ch {
	case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
		return rdn()
	case '+':
		return  exp(2)
	case '-':
		return -exp(2)
	case '(':
		res := exp(1)
		ch = getch()
		return res
	case:
		error("Bad expression"); return -1	// TODO: retval
	}
}

exp :: proc(n: int) -> int {
	a := bexp()
	for {
		switch ch {
		case int('*'): if n < 3 { a = a * exp(3); continue }
		case int('/'): if n < 3 { a = a / exp(3); continue }
		case int('%'): if n < 3 { a = a % exp(3); continue }
		case int('+'): if n < 2 { a = a + exp(2); continue }
		case int('-'): if n < 2 { a = a - exp(2); continue }
		case:
			if n > 1 || (n == 1 && ch == int(')')) || (n == 0 && ch == s_eom) {
				return a
			}
			error("Bad expression")
		}
		return a
	}
}

wrn :: proc(ni: int) { n := ni		// since n is not writable in Odin
	if n < 0 { putch(int('-')); n = -n }
	if n > 9 { wrn(n/10) }
	putch((n % 10) + int('0'))
}

wrc :: proc(ci: int) { c := ci		// since c is not writable in Odin
	if ch == '\n' { newline(); chpos = 0; return }
	if chpos > 70 { wrc('\n') }
	if 32<=ch && ch<127 {	// Assume 7 bit ASCII.
	} else { ch = '?' }
	wrch(i32(ch))
	chpos = chpos+1
}

wrs :: proc(s: string) { for c in s { wrc(int(c)) } }

// TODO: XXX : selectoutput
error :: proc(mess: string) {
	// selectoutput(sysout)
	wrs("\nError: "); wrs(mess)
	wrs("\nActive calls:\n"); btrace(p, 20)
	wrs("\nIncomplete calls: ")
	if f==0 { wrs("none") } else { prcall(20, f, h, s) }
	wrs("\nEnvironment:\n"); wrenv(e, 8)
	wrs("End of error message\n")
	// selectoutput(tostream)
}

prcall :: proc(n, f, h, s: int) { if f == 0 { return }
	if n == 0 { wrs("...") }
	else { prcall(n-1, base[f], base[f+1], f-1)
		base[h] = s-h
		wrcall(f+4, s)
	}
}

btrace :: proc(pi, ni: int) { p, n := pi, ni	// since pi and ni are not writable
	for {
		if n == 0 { wrs("...\n") }
		if p == 0 || n == 0 { return }
		wrcall(p+4, base[p+3]); wrc(c_apply); wrc('\n')
		p, n = base[p], n-1
	}
}

wrcall :: proc(ai: int, b: int) { a := ai	// since ai is not writable
	sep := c_call
	for a < b {
		wrc(sep); //wrarg(a)
		a = a + base[a] + 1
		sep = c_sep
	}
}

wrarg :: proc(a: string) { fmt.print(a) }

wrenv :: proc(e, n: int) {
	if n == 0 || e == 0 { return }
	wrs("Name: ");    //wrarg(arg(e+2, 0))
	wrs("  Value: "); //wrarg(arg(e+2, 1))
	wrc('\n')
	wrenv(base[e], n-1)
}

prstate :: proc() {
	fmt.print("\nS Stack    f=%n h=%n s=%n\n", f, h, s, t, p, e)
	for q := 0; q<s; q+=1 {
		x := base[q]
		if q % 10 == 0 { fmt.print("\n{}:", q) }
		fmt.print(" {}", x)
		if 32<=x && x<=127 { fmt.print("{}", x) } else { fmt.print("  ") }
	}
	newline()

	fmt.print("\nT Stack    t=%n p=%n e=%n*n", t, p, e)
	for q := t+1; q<upb; q+=1 {
		x := base[q]
		if ((q-t-1) % 10 == 0) { fmt.print("\n{}:", q) }
		fmt.print(" {}", x)
		if 32<=x && x<=127 { fmt.print("=%c", x) } else { fmt.print("  ") }
	}
	newline()

	fmt.printf("Def chain*n")
	{
		q := e
		for q != 0 {
			a := q+2		// Macro name;
			fmt.printf("%i7: ", q)
			//item(a)
			fmt.printf(" = ")
			//item(a+base[a]+1)	// Macro value
			newline()
			q = base[q]		// next defition;
		}
		// abort(1000); TODO: XXX
	}
}

item :: proc(x: string) {
	for q in x {
                if (32<=ch && ch<127)  { wrc(ch) } else { wrc(ch) }
        }
}

main :: proc() {
	upb = 2_000_000
	base = make([]int, upb)
	defer delete(base)

	bgpm()
}
