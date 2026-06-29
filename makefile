all : bgpm
	./bgpm < bgpm.odin
bgpm : bgpm.odin
	odin build .
