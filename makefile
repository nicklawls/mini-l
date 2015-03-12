## all: update parser
all: parser

run: all
	./parser

debug:
	gdb ./parser

parser_debug: flexfile
	touch *
	gcc -o parser y.tab.c lex.yy.c -g -lfl

parser: flexfile
	touch *
	gcc -o parser y.tab.c lex.yy.c -lfl

flexfile: bisonfile mini_l.lex y.tab.h
	flex mini_l.lex

bisonfile: mini_l.y
	bison -v -d --file-prefix=y mini_l.y

clean:
	rm -rf *.c *.o *.output parser

## update:
##	git pull

## push:
##	git commit -am "automated commit"
##	git push