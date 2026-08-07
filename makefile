all : bgpm
	./bgpm < inp > out
	cmp out exp
	./bgpm < collatz.inp > collatz.out
	cmp collatz.out collatz.exp
	./bgpm < defs.inp > defs.out
	cmp defs.out defs.exp
	./bgpm < hanoi.inp > hanoi.out
	cmp hanoi.out hanoi.exp
	./bgpm < perm.inp > perm.out
	cmp perm.out perm.exp
	./bgpm < prime.inp > prime.out
	cmp prime.out prime.exp
bgpm : bgpm.odin
	odin build .

clean :
	rm bgpm out collatz.out defs.out hanoi.out perm.out prime.out
