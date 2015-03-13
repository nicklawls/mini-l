## all: update parser
all: min2mil

run: all
	./min2mil

min2mil: flexfile 
	touch *
	gcc -o min2mil y.tab.c lex.yy.c -lfl

flexfile: bisonfile mini_l.lex y.tab.h codegen.h symbol_table.h
	flex mini_l.lex

bisonfile: mini_l.y
	bison -v -d --file-prefix=y mini_l.y

clean:
	rm -rf *.c *.o *.output parser