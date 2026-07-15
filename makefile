all : bgpm
	./bgpm < inp > out
	cmp out exp
bgpm : bgpm.odin
	odin build .
