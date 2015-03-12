%option yylineno

%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "y.tab.h"
	const char *reserved_words[] = {"and","array","beginloop","beginprogram","break","continue","do","else","elseif","endif","endloop","endprogram","exit","false","if","integer","not","of","or","program","read","then","true","while","write"};
	typeof(IDENT) reserved_tokens[] = {AND,ARRAY,BEGINLOOP,BEGIN_PROGRAM,BREAK,CONTINUE,DO,ELSE,ELSEIF,ENDIF,ENDLOOP,END_PROGRAM,EXIT,FALSE,IF,INTEGER,NOT,OF,OR,PROGRAM,READ,THEN,TRUE,WHILE,WRITE};
	size_t keywords = 25;
	int yycolumno = 1;
%}

NEWLINE \n

COMMENT ##.*

WHITESPACE [ \t]

ARITHMETIC [-+*/%]

COMPARISON ==|<>|<|>|<=|>=

DIGIT [0-9]

NUMBER 0|[1-9]{DIGIT}*

LETTER [A-Z]|[a-z]

IDENTIFIER ({LETTER})({LETTER}|{DIGIT})*(_*({LETTER}|{DIGIT})+)*

SPECIAL [;:,?\[\]\(\)]|(:=) 

UNIDENTIFIED .

INVALID_IDENT {DIGIT}+{IDENTIFIER}_*|{DIGIT}*{IDENTIFIER}_+
%%
{NEWLINE} {yycolumno = 1;}

{NUMBER} {
	yycolumno += yyleng;
	yylval.intval = atoi(yytext);
	return NUMBER;
}

{COMPARISON} {
	yycolumno += yyleng;
	// yylval.stringval = yytext;

	if (!strcmp(yytext, "==") ) {
		return EQ;
	} else if (!strcmp(yytext, "<>") ) {
		return NEQ;
	} else if (!strcmp(yytext, ">") ) {
		return GT;
	} else if (!strcmp(yytext, "<") ) {
		return LT;
	} else if (!strcmp(yytext, "<=") ) {
		return LTE;
	} else if (!strcmp(yytext, ">=") ) {
		return GTE;
	} else {
		printf("Invalid comparison operator\n");
		exit(1);
	}
}

{ARITHMETIC} {
	yycolumno += yyleng;
	// yylval.stringval = yytext;

	if (!strcmp(yytext, "-") ) {
		return SUB;
	} else if (!strcmp(yytext, "+") ) {
		return ADD;
	} else if (!strcmp(yytext, "*") ) {
		return MULT;
	} else if (!strcmp(yytext, "/") ) {
		return DIV;
	} else if (!strcmp(yytext, "%") ) {
		return MOD;
	} else {
		printf("invalid arithmetic operator\n");
		exit(1);
	}
}

{SPECIAL} {
	yycolumno += yyleng;
	// yylval.stringval = yytext;

	if (!strcmp(yytext, ";") ) {
		return SEMICOLON;
	} else if (!strcmp(yytext, ":") ) {
		return COLON;
	} else if (!strcmp(yytext, ",") ) {
		return COMMA;
	} else if (!strcmp(yytext, "?") ) {
		return QUESTION;
	} else if (!strcmp(yytext, "[") ) {
		return L_BRACKET;
	} else if (!strcmp(yytext, "]") ) {
		return R_BRACKET;
	} else if (!strcmp(yytext, "(") ) {
		return L_PAREN;
	} else if (!strcmp(yytext, ")") ) {
		return R_PAREN;
	} else if (!strcmp(yytext, ":=") ) {
		return ASSIGN;
	} else {
		printf("invalid special character\n");
		exit(1);
	}
}

{IDENTIFIER} {
	yycolumno += yyleng;

	int i;
	for (i = 0; i < keywords; i++) {
		if (!strcmp(yytext, reserved_words[i])) {
			return reserved_tokens[i];
		} 
	} 
	
	strcpy(yylval.strval,yytext); // seems to be working
	return IDENT;
}

{COMMENT}|{WHITESPACE} /* consume whitespace and comments */

{UNIDENTIFIED} {
	printf("Invalid character \"%s\" on line %i, column %i\n", yytext, yylineno, yycolumno);
	exit(1);
}

{INVALID_IDENT} {
	printf("Invalid identifier \"%s\" on line %i, column %i\n", yytext, yylineno, yycolumno);
	exit(1);
}

%%


