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
	# works but takes a bit of time: ~7s
	# disable for now so the make finishes quickly
	#./bgpm < prime.inp > prime.out
	#cmp prime.out prime.exp
	./bgpm < sum.inp > sum.out
	cmp sum.out sum.exp
	./bgpm < t1.inp > t1.out
	cmp t1.out t1.exp
bgpm : bgpm.odin
	odin build .

clean :
	rm -f bgpm out collatz.out defs.out hanoi.out perm.out prime.out sum.out t1.out
