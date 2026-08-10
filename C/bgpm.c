/*
 * A C implementation of Martin Richards' BGPM (BCPL? General Purpose
 * Macrogenerator) converted from the BCPL version at:
 *      https://github.com/8l/bcpl file: bcplprogs/bgpm/bgpm.b
 * which in turn was based on (and the bugs fixed up from) the CPL
 * version in Christopher J. Strachey's '65 GPM paper.
 *
 * The BCPL to C conversion was based on the version in Odin which
 * is available in the parent directory.
 *
 * Copyright (c) 2026 Charles E. Suresh, Martin Richards
 *
 * Licence: AGPLv3
 * SPDX-License-Identifier: AGPL-3.0-only
 * Please see the LICENSE file for the Affero GPL 3.0 license details
 */

#include <stdio.h>	// getchar, putchar, FILE * etc
#include <string.h>	// strlen
#include <stdlib.h>	// malloc, free

// GLOBAL {

int s, h, f, t, p, e, c;
char ch;
FILE *sysin, *sysout, *fromstream, *tostream;
int *base;
int upb;
int chpos;
int tracing;

// GLOBAL }

// MANIFEST {

#define s_eof		-1
#define s_eom		-2
#define s_def		-3
#define s_set		-4
#define s_eval		-5
#define s_lquote	-6
#define s_rquote	-7

#define c_call		'{'
#define c_apply		'}'
#define c_sep		' '
#define c_skip		'~'
#define c_lquote	'['
#define c_rquote	']'
#define c_arg		'$'

// MANIFEST }

void error(const char *mess);
int rdn();
void wrs(const char *str);
void wrarg(int);
void wrn(int);
int fexp(int);
int bexp();
void btrace(int, int);
void prcall(int, int, int, int);
void wrenv(int, int);
void wrcall(int, int);
void item(int);

#define rdch getchar
#define wrch putchar
#define newline() putchar('\n')

int
push(int ch) {
	if (t == s) { error("Insufficient work space"); }
	base[++s] = ch;
	return s;
}

void
putch(int ch) { if (h == 0) { wrch(ch); } else { push(ch); } }

int
getch() {
	int ch;
	if (c) { return base[++c]; }

	ch = rdch();

	while (ch == c_skip) {
		// Ignore all character until the end of the line
		do { ch = rdch(); } while ((ch != '\n') && (ch != '\r') && (ch != EOF));
		// Now ignore all white space characters
		while (ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t') { ch = rdch(); }
	}

	return ch;
}

int
arg(int a, int n) {
	for (;;) {
		if (base[a] < 0) error("Too few arguments");
		if (n == 0) return a;
		a = a+base[a]+1; n--;
	}
}

int
lookup(int a) {
	int q = e; int i = 0; int len = base[a];
	while (q != 0 && i <= len) {
		if (base[q+i+2] == base[a+i]) { i++; } else { q = base[q]; i = 0; }
	}
	if (q == 0) error("Macro not defined");
	return q;
}

void
macro(const char *name, int code) {
	// Define a builtin macro
	int s1 = s, len = strlen(name);
	push(e); push(t);
	push(len); for (int i = 1; i <= len; i++) { push(name[i - 1]); }
	push(1); push(code); push(s_eom);
	while (s != s1) { base[t--] = base[s--]; }
	e = t+1;
}

void
bgpm(void) {
	s = -1; t = upb; h = 0; p = 0; f = 0; e = 0; c = 0;

	macro("def", s_def);
	macro("set", s_set);
	macro("eval", s_eval);
	macro("lquote", s_lquote);
	macro("rquote", s_rquote);
	macro("eof", s_eof);

	for (;;) {				// Start of main scanning loop.
		ch = getch();

sw:		switch (ch) {
			default: putch(ch); continue;

			case c_lquote:	{	// {
//writef("lquote\n");
				int d = 1;
				for (;;) {
					ch = getch();
					if (ch < 0) error("Non character in quoted string");
					if (ch == c_lquote) d++;
					if (ch == c_rquote) { d--; if (d == 0) break; }
					putch(ch);
				}
//writef("rquote\n");
				continue;
			}

			case c_call:		// [
//writef("Call\n");
				// NEW: save current e and t so that definitions created
				// by the call can be preserved while local definitions
				// are removed.  See s_eom.
				f = push(f); push(h); push(e); push(t);
				h = push(0);
				continue;

			case c_sep:		// \
//writef("Sep\n");
				if (h == 0) { putch(ch); continue; }
				base[h] = s-h;
				h = push(0);
				continue;

			case c_arg:	{	// ^
//writef("Arg\n");
				if (p == 0) { putch(ch); continue; }
				ch = getch();
				int a = arg(p+4, rdn());
				for (int q = 1; q <= base[a]; q++) { putch(base[a+q]); }
				goto sw;
			}

			case c_apply:	{	// ]
//writef("Apply\n");
				int a = f;
				if (h == 0) { putch(ch); continue; }
				base[h]= s-h;
				push(s_eom);
				f = base[a]; h = base[a+1];	// Restore the previous f and h
				base[a] = p; base[a+1] = c;	// a!2, a!3 contain e, t when [ was encountered
				while (s >= a) { base[t--] = base[s--]; }
				p = t+1;
				c = arg(lookup(p+4)+2, 1);
				if (tracing) {
					int i = 0;
					int a = p+4;	// Pointer to arg 0
					wrs("\nCalling macro\n");
					while (base[a] >= 0) {
						printf("arg %2d: ", i);
						wrarg(a);
						newline();
						a = a + base[a] + 1;
						i++;
					}
//prstate();
				}
				continue;
			}

			case s_lquote: putch(c_lquote); continue;
			case s_rquote: putch(c_rquote); continue;

			case s_eof: return;

			case s_eom:	{
//writef("Eom\n");
ret:				if (p == 0) continue;
				int a = t;
				int q = p-1;
				int n = base[p+3] - p + 1;	// This is the distance that the new
								// definitions will be moved by, as
								// a result of removing the call and
								// local definitions.
				base[a] = e;
				for (;;) {
					int na = base[a];
					if (na > p) break;
					// na points to a new definition
					base[a] = na + n;	// Adjust this pointer
					a = na;
				}
				base[a] = base[p+2];	// Unlink the local definitions from the chain, if any.
				e = base[t];		// Get the (possible) new e.

				a = t;
				t = base[p+3];
				c = base[p+1];
				p = base[p];

				// Copy the new definitions, if any.
				while (q > a) {
					base[t--] = base[q--];
				}

//prstate();
				continue;
			}

			case s_def:	{
//writef("Def\n");
				int a1 = arg(p+4, 1);
				int a2 = arg(p+4, 2);
				int ne = a1 - 2;	// ne -> [e0, end, <name> <val> ]
				// Find end of definition
				int q = p+4;
				while (base[q] >= 0) q = q+base[q]+1;
				// q points to the eom at the end of the call.
				// Put eom at end of second argument.
				base[a2+base[a2]+1] = s_eom;
				base[ne] = e; base[ne+1] = q;
				e = ne;
				c = base[p+1]; t = e-1;
				p = base[p];
//writef("def: e=%n ", e);
//item(a1);
//newline();
				continue;
			}

			case s_set:	{
//writef("Set\n");
				int name = arg(p+4, 1);
				int val = arg(p+4, 2);
				int len = base[val];
				int a = lookup(name);
				int b = arg(a+2, 1);
				int max = base[a+1] - b - 1;	// Max length of the value.
				if (len > max) error("New value too long");
				for (int i = 0; i <= len; i++) base[b+i] = base[val+i];
				base[b+len+1] = s_eom;
				goto ret;
			}

			case s_eval:
//writef("Eval\n")
				c = arg(p+4, 1);
				wrn(fexp(0));
				goto ret;
		}
	}
}

int
rdn() {
	int val = 0;
	while ('0' <= ch && ch <= '9') {
		val = 10*val + ch - '0';
		ch = getch();
	}
	return val;
}

int
bexp() {
	ch = getch();

	switch (ch) {
		default:
			error("Bad expression");
		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			return rdn();

		case '+': return  fexp(2);
		case '-': return -fexp(2);

		case '(':{
			int res = fexp(1);
			ch = getch();
			return res;
		}
	}
}

int
fexp(int n) {
	int a = bexp();
	for (;;) {
		switch (ch) {
			case '*': if (n < 3) { a = a * fexp(3); continue; } return a;
			case '/': if (n < 3) { a = a / fexp(3); continue; } return a;
			case '%': if (n < 3) { a = a % fexp(3); continue; } return a;
			case '+': if (n < 2) { a = a + fexp(2); continue; } return a;
			case '-': if (n < 2) { a = a - fexp(2); continue; } return a;
			default : if (n > 1 || (n == 1 && ch == ')') || (n == 0 && ch == s_eom)) return a;
				  error("Bad expression");
		}
	}
}

void
wrn(int n) {
	if (n < 0) { putch('-'); n = -n; }
	if (n > 9) wrn(n / 10);
	putch(n % 10 + '0');
}

void
wrc(int ch) {
	if (ch == '\n') { newline(); chpos = 0; return; }
	if (chpos > 70) wrc('\n');
	if (!(' ' < ch && ch <= 127)) ch = '?';	// Assume 7 bit ASCII.
	wrch(ch);
	chpos++;
}

void
wrs(const char *s) {
	while (*s) { wrc(*s++); }
}

// TODO: XXX : selectoutput, longjmp?
void
error(const char *mess) {
	//selectoutput(sysout);
	wrs("\nError: "); wrs(mess);
	wrs("\nActive calls:\n"); btrace(p, 20);
	wrs("\nIncomplete calls: ");
	if (f == 0) wrs("none"); else prcall(20, f, h, s);
	wrs("\nEnvironment:\n"); wrenv(e, 8);
	wrs("End of error message\n");
	//selectoutput(tostream);
	//longjump(rec_p, rec_l);
}

void
prcall(int n, int f, int h, int s) {
	if (f != 0) {
		if (n == 0) wrs("...");
		else {
			prcall(n-1, base[f], base[f+1], f-1);
			base[h] = s-h;
			wrcall(f+4, s);
		}
	}
}

void
btrace(int p, int n) {
	for (;;) {
		 if (n == 0) wrs("...\n");
		 if (p == 0 || n == 0) return;
		 wrcall(p+4, base[p+3]); wrc(c_apply); wrc('\n');
		 p = base[p]; n--;
	}
}

void
wrcall(int a, int b) {
	int sep = c_call;
	while (a < b) {
		wrc(sep); wrarg(a);
		a = a + base[a] + 1;
		sep = c_sep;
	}
}

void
wrarg(int a) {
	for (int ptr = 1; ptr <= base[a]; ptr++) { wrc(base[ptr+a]); }
}

void
wrenv(int e, int n) {
	if (n == 0 || e == 0) return;
	wrs("Name: ");    wrarg(arg(e+2, 0));
	wrs("  Value: "); wrarg(arg(e+2, 1));
	wrc('\n');
	wrenv(base[e], n-1);
}

void
prstate() {
	printf("\nS Stack    f=%d h=%d s=%d\n", f, h, s, t, p, e);
	for (int q = 0; q<s; q++) {
		int x = base[q];
		if (q % 10 == 0) { printf("\n%d:", q); }
		printf(" %d", x);
		if (32<=x && x<=127) { printf("=%c", x); } else { printf("  "); }
	}
	newline();

	printf("\nT Stack    t=%d p=%d e=%d\n", t, p, e);
	for (int q = t+1; q<upb; q++) {
		int x = base[q];
		if ((q-t-1) % 10 == 0) { printf("\n%d:", q); }
		printf(" %d", x);
		if (32<=x && x<=127) { printf("=%c", x); } else { printf("  "); }
	}
	newline();

	printf("Def chain\n");
	{
		int q = e;
		while (q) {
			int a = q+2;		// Macro name;
			printf("%d: ", q);
			item(a);
			printf(" = ");
			item(a+base[a]+1);	// Macro value
			newline();
			q = base[q];		// next defition;
		}
		// abort(1000); TODO: XXX
	}
}

void
item(int x) {
	for (int q = x+1; q <= x+base[x]; q++) {
		int ch = base[q];
		if (32 <=ch && h < 127) {
			printf("%c", ch);
		} else {
			printf(" %d ", ch);
		}
	}
}

int
main(int argc, char *argv[]) {
	upb = 2000000;
	base = malloc((upb+1)*sizeof(int));
	if (!base) {
		fprintf(stderr, "Unable to allocate work space\n");
		exit(1);
	}

	sysin = stdin;
	sysout = stdout;
	fromstream = sysin;
	tostream = sysout;

	bgpm();

	if (fromstream != sysin) fclose(fromstream);
	if (tostream != sysout) fclose(tostream);
	free(base);
	return 0;
}
