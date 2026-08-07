all : bgpm
	./bgpm < inp > out
	cmp out exp
	./bgpm < collatz.inp > collatz.out
	cmp collatz.out collatz.exp
	./bgpm < defs.inp > defs.out
	cmp defs.out defs.exp
bgpm : bgpm.odin
	odin build .

clean :
	rm bgpm out collatz.out defs.out
