%{
	#include <stdio.h>
	#include <stdlib.h>
  #include "symbol_table.h"
  #include "codegen.h"
	void yyerror(const char *message);
  extern int yylineno;
  extern int yycolumno;
  FILE* yyin;
  FILE* yyout;
  int verbose = 0;
  int sout = 0;
  int errcount = 0;
  char program[2048];
%}

%union{
	int intval;
  char strval[64];
  struct variable {
    char strval[16];
    char code[512];
  } variable;
  struct expr {
    char place[8];
    char code[512];
  } expr;
  struct stmt {
    char begin[16];
    char code[2048];
    char after[256];
    char continue_to[256]; // inherit test address of nearest enclosing loop
    char break_to[256]; // inherit end of nearest enclosing loop
  } stmt; 
  struct strlist {
    char list[64][64];
    int length;
    char code[64];
  } strlist;

}

%error-verbose
%start input
%token <intval> NUMBER
%token <strval> IDENT
%token SEMICOLON BEGIN_PROGRAM END_PROGRAM ASSIGN L_PAREN R_PAREN COLON
%token INTEGER PROGRAM L_BRACKET R_BRACKET
%token ARRAY OF IF THEN ENDIF ELSE ELSEIF WHILE DO BEGINLOOP BREAK CONTINUE ENDLOOP
%token EXIT READ WRITE 
%token COMMA QUESTION TRUE FALSE
%left AND OR NOT EQ NEQ LT GT LTE GTE
%left ADD 
%left SUB
%left MULT 
%left DIV
%left MOD

%type <expr> expression
%type <expr> term termA
%type <expr> m_exp relation_exp relation_expA
%type <expr> relation_and_exp bool_exp 
%type <strval> comp   
%type <strlist> var_list id_list
%type <stmt> statement stmt_list decl_list elif_list
%type <stmt> block  
%type <stmt> Program declaration
%type <variable> var

%%
input : Program {
          strcpy(program, $1.code);
          if (verbose) {printf("input -> Program\n");}
        }
      ;

Program : PROGRAM IDENT SEMICOLON block END_PROGRAM {
          
          declare_temps($$.code); // declaration statements for temporaries
          
          strcat($$.code, $4.code);
          char end[16];
          gen2(end, ":", "ENDLABEL");
          strcat($$.code, end); // concat declaration of endlabel
            if (verbose || sout) {
              printf("Program -> program ident ; block endprogram\n");
              printf("%s\n\n", $$.code);
            }
          }
        ;

block : decl_list BEGIN_PROGRAM stmt_list {
          strcpy($$.begin, $1.begin);
          strcpy($$.after, $3.after);
          strcpy($$.code, $1.code);
          strcat($$.code, $3.code);
          if (verbose) {
            printf("block -> decl_list beginprogram stmt_list\n");
            printf("%s\n\n", $$.code);
          }
        }
      ;

decl_list : declaration SEMICOLON {
              strcpy($$.begin, $1.begin);
              strcpy($$.after, $1.after);
              strcpy($$.code, $1.code);
              
              if (verbose) {
                printf("decl_list -> declaration ;\n");
                printf("%s\n\n", $$.code);
              }
            }
          | declaration SEMICOLON decl_list {
              strcpy($$.begin, $1.begin);
              strcpy($$.after, $3.after);
              strcpy($$.code, $1.code);
              strcat($$.code, $3.code);
              if (verbose) {
                printf("decl_list -> declaration ; decl_list\n");
                printf("%s\n\n", $$.code);
              }
            }
          ;

declaration : id_list COLON INTEGER {
                
                char declare[32];

                int i = 0;
                while(i < $1.length) {
                  gen2(declare, ".", $1.list[i]);
                  strcat($$.code, declare);
                  if (symtab_put($1.list[i], 0, 0)) { // name, type int, not temp
                    yyerror("Attempted to redeclare a declared variable\n");
                  } 
                  i++;
                }

                if (verbose) {
                  printf("declaration -> id_list : integer\n");
                  printf("%s\n\n", $$.code);
                }
              }
            | id_list COLON ARRAY L_BRACKET NUMBER R_BRACKET OF INTEGER {

                char declare[32];

                int i = 0;
                while(i < $1.length) {

                  if ($5 == 0) {
                    yyerror("Arrays must have positive nonzero size\n");
                  }

                  gen3i(declare, ".[]", $1.list[i], $5);
                  strcat($$.code, declare);
                  if (symtab_put($1.list[i], 1, 0)) { // name, type int, not temp
                    yyerror("Attempted to redeclare a declared variable\n");
                  } 
                  i++;
                }

                if (verbose) {
                  printf("declaration -> id_list : array [number] of integer\n");
                  printf("%s\n\n", $$.code);
                }
              }
            ;

id_list : IDENT {
            $$.length = 1;
            strcpy($$.list[0], $1);
            if (verbose) {
              printf("id_list -> ident\n");
            }
          }
        | IDENT COMMA id_list { // something fishy happening
            $$.length = $3.length + 1;
            strcpy($$.list[0], $1);
            int i = 1;
            while (i <= $3.length) { 
              // doesn't matter what order they're in, could be changed
              strcpy($$.list[i], $3.list[i-1]);
              i++;
            }
            if (verbose) {
              printf("id_list -> ident, id_list\n");
            }
          }
        ;

elif_list : ELSEIF bool_exp stmt_list {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin); // declare label first
              strcat($$.code, $2.code); // add code to compute expression
              char ifthen[64], gotoend[64], end[64];
              gen3(ifthen, "?:=", $3.begin, $2.place );
              gen2(gotoend, ":=", $$.after);
              strcat($$.code, ifthen);
              strcat($$.code, gotoend);
              strcat($$.code, $3.code);
              gen2(end, ":", $$.after);
              strcat($$.code, end);             

              if (verbose) {
                printf("elif_list -> elseif bool_exp stmt_list\n");
                printf("%s\n\n", $$.code);
              }
            }
          | ELSEIF bool_exp stmt_list ELSE stmt_list {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              strcat($$.code, $2.code);
              char ifthen[64], elsethen[64], gotoend[64], end[64];
              gen3(ifthen, "?:=", $3.begin, $2.place);
              strcat($$.code, ifthen);
              gen2(elsethen, ":=", $5.begin);
              strcat($$.code, elsethen);
              strcat($$.code, $3.code);
              gen2(gotoend, ":=", $$.after);
              strcat($$.code, gotoend);
              strcat($$.code, $5.code);
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              if (verbose) {
                printf("elif_list -> elseif bool_exp stmt_list ELSE stmt_list\n");
                printf("%s\n\n", $$.code);
              } 
            } 
          | ELSEIF bool_exp stmt_list elif_list {
              newlabel($$.begin);
              strcpy($$.after, $4.after);
              gen2($$.code, ":", $$.begin); // declare label first
              strcat($$.code, $2.code); // add code to compute expression
              char ifthen[64], gotonext[64], gotoend[64];
              gen3(ifthen, "?:=", $3.begin, $2.place );
              strcat($$.code, ifthen); // if its a hit, execute stmt_list and go to the very end
              gen2(gotonext, ":=", $4.begin); 
              strcat($$.code, gotonext); // if not a hit, skip to next elif
              strcat($$.code, $3.code); // code for statement list
              gen2(gotoend, ":=", $$.after);
              strcat($$.code, gotoend); // skip to the very end when done
              strcat($$.code, $4.code); // rest of the list
              
              if (verbose) {
                printf("elif_list -> elseif bool_exp stmt_list elif_list\n");
                printf("%s\n\n", $$.code);
              }
            }
          
          ;

stmt_list : statement SEMICOLON {
              strcpy($$.begin, $1.begin);
              strcpy($$.after, $1.after);
              strcpy($$.code, $1.code);

              if (verbose) {
                printf("stmt_list -> statement;\n");
                printf("%s\n\n", $$.code);
              }
            }
          | statement SEMICOLON stmt_list {
              strcpy($$.begin, $1.begin);
              strcpy($$.after, $3.after);
              strcpy($$.code, $1.code);
              strcat($$.code, $3.code);

              if (verbose) {
                printf("stmt_list -> statement; stmt_list\n");
                printf("%s\n\n", $$.code);
              }
          }
          ;


var_list : var {
            $$.length = 1;
            strcpy($$.list[0], $1.strval);
            strcpy($$.code, $1.code);
            if (verbose) {
              printf("var_list -> var\n");
              printf("%s\n", $$.list[0]);
            }
          }
         | var COMMA var_list {
            $$.length = $3.length + 1;
            strcpy($$.list[0], $1.strval);
            int i = 1;
            while (i <= $3.length) { 
              // transfers inorder for the  id_list, should hold for this as well
              strcpy($$.list[i], $3.list[i-1]);
              i++;
            }

            strcat($$.code, $1.code);
            if (verbose) {
              printf("var_list -> var, var_list\n");
              int j = 0;
              while(i < $$.length) {
                printf("%s\n", $$.list[j]); ++j;
              }
            }
          }
         ;

statement : EXIT {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              
              char kill[8];
              gen2(kill, ":=", "ENDLABEL");
              strcat($$.code, kill);

              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);
              
              if (verbose) {
                printf("statement -> exit\n");
                printf("%s\n\n", $$.code);
              }
            }
          | BREAK {
            newlabel($$.begin);
            newlabel($$.after);
            gen2($$.code, ":", $$.begin);
            char end[8];
            gen2(end, ":", $$.after);
            strcat($$.code, end);

            yyerror("Break and Continue not supported\n");

            if (verbose) {
              printf("statement -> break\n");
            }
          }
          | CONTINUE {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              yyerror("Break and Continue not supported\n");

              if (verbose) {
                printf("statement -> continue\n");
              }
            }
          | READ var_list {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              strcat($$.code, $2.code);

              char io[32];
              int i = 0;
              while(i < $2.length) {
                int index = symtab_get($2.list[i]); // have to delimit on comma in case of array
                if (index == -1) {
                  yyerror("attempted to retrieve a symbol not in table\n");
                  printf("offending symbol: %s", $2.list[i]);
                }

                int comma_loc = strcspn($2.list[i], ",");
                int length = strlen($2.list[i]);

                if (symtab_entry_is_int(index)) {
                  if (length > comma_loc) {
                    yyerror("Specified index for non-array variable\n");
                  }  
                  gen2(io, ".<", $2.list[i]);
                } else {
                  
                  if (comma_loc == length) { 
                    yyerror("Attempted array access without index\n");
                  }
                  gen2(io, ".[]<", $2.list[i]); // should have dst,index
                }
                strcat($$.code, io);
                ++i;
              }

              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);
              if (verbose) {
                printf("statement -> read var_list\n");
                printf("%s\n\n", $$.code);
              }
            }
          | WRITE var_list {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              strcat($$.code, $2.code);

              char io[32];
              int i = 0;
              while(i < $2.length) {
                int index = symtab_get($2.list[i]); // have to delimit on comma in case of array
                if (index == -1) {
                  yyerror("attempted to retrieve a symbol not in table\n");
                  printf("offending symbol: %s", $2.list[i]);
                }

                int comma_loc = strcspn($2.list[i], ",");
                int length = strlen($2.list[i]);
                
                if (symtab_entry_is_int(index)) {
                  if (length > comma_loc) {
                    yyerror("Specified index for non-array variable\n");
                  }  
                  gen2(io, ".>", $2.list[i]);
                } else {
                  if (comma_loc == length) { 
                    yyerror("Attempted array access without index\n");
                  }
                  gen2(io, ".[]>", $2.list[i]); // should have dst,index
                }
                strcat($$.code, io);
                ++i;
              }

              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);
              if (verbose) {
                printf("statement -> write var_list\n");
                printf("%s\n\n", $$.code);
              }
            }
          | DO BEGINLOOP stmt_list ENDLOOP WHILE bool_exp {
              newlabel($$.begin);
              newlabel($$.after);

              gen2($$.code, ":", $$.begin);

              strcat($$.code, $3.code);
              strcat($$.code, $6.code);

              char loop[64], end[64];
              gen3(loop, "?:=", $$.begin, $6.place);
              strcat($$.code, loop);
              
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              if (verbose) {
                printf("statement -> do beginloop stmt_list endloop while bool_exp\n");
                printf("%s\n\n", $$.code);
              }
            }
          
          | WHILE bool_exp BEGINLOOP stmt_list ENDLOOP {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              strcat($$.code, $2.code);
              char decide[64], loopback[64], gotoend[64], end[64];

              // skip around gotoend if yes, fall into gotoend if no
              gen3(decide, "?:=", $4.begin, $2.place);
              strcat($$.code, decide);

              gen2(gotoend, ":=" , $$.after);
              strcat($$.code, gotoend);

              strcat($$.code, $4.code);

              gen2(loopback, ":=", $$.begin); // evaluate bool again
              strcat($$.code, loopback);
              
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              if (verbose) {
                printf("statement -> while bool_exp beginloop stmt_list endloop\n");
                printf("%s\n\n", $$.code);
              }
            }
          | var ASSIGN expression {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);
              
              int index = symtab_get($1.strval); // have to delimit on comma in case of array
              strcat($$.code, $3.code);
              if (index >= 0) {
                char assign[64];
                
                int comma_loc = strcspn($1.strval, ",");
                int length = strlen($1.strval);
                if (symtab_entry_is_int(index)) {
                  if (length > comma_loc) {
                    yyerror("Specified index for non-array variable\n");
                  }  
                  gen3(assign, "=", $1.strval, $3.place);
                } else {
                  if (comma_loc == length) { 
                    yyerror("Attempted array access without index\n");
                  }
                  strcat($$.code, $1.code);

                  gen3(assign, "[]=", $1.strval, $3.place); 
                }
                strcat($$.code, assign);
              } else {
                yyerror("attempted to retrieve a symbol not in table\n");
                printf("offending symbol: %s\n", $1 );
              }

              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);
              if (verbose) {
                printf("statement -> var := expression\n");
                printf("%s\n\n", $$.code);
              }
            }
          | var ASSIGN bool_exp QUESTION expression COLON expression {
              
              int index = symtab_get($1.strval); // have to delimit on comma in case of array
              strcpy($$.code, $3.code);

              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin);

              if (index >= 0) {
                char optionA[8], optionB[8], assign[32];
                newlabel(optionA);
                newlabel(optionB);
                
                strcat($$.code, $3.code); // compute expr
                char ifthen[32], elsethen[32], toend[32], A[8], B[8], end[32];  
                gen3(ifthen, "?:=", optionA, $3.place);
                strcat($$.code, ifthen);
                gen2(elsethen, ":=", optionB);
                strcat($$.code, elsethen);
                gen2(A, ":", optionA);
                strcat($$.code, A);
                strcat($$.code, $5.code);
                
                int comma_loc = strcspn($1.strval, ",");
                int length = strlen($1.strval);

                if (symtab_entry_is_int(index)) {
                  if (length > comma_loc) {
                    yyerror("Specified index for non-array variable\n");
                  }  
                  gen3(assign, "=", $1.strval, $5.place);
                } else {
                  if (comma_loc == length) { 
                    yyerror("Attempted array access without index\n");
                  }
                  strcat($$.code, $1.code);
                  gen3(assign, "[]=", $1.strval, $5.place);
                }
                
                strcat($$.code, assign);
                gen2(toend, ":=", $$.after);
                strcat($$.code, toend);
                gen2(B, ":", optionB);
                strcat($$.code, B);
                strcat($$.code, $7.code);
                if (symtab_entry_is_int(index)) {
                  if (length > comma_loc) {
                    yyerror("Specified index for non-array variable\n");
                  }  
                  gen3(assign, "=", $1.strval, $7.place);
                } else {
                  if (comma_loc == length) { 
                    yyerror("Attempted array access without index\n");
                  }
                  strcat($$.code, $1.code);
                  gen3(assign, "[]=", $1.strval, $7.place);
                }
                strcat($$.code, assign);
                gen2(end, ":", $$.after);
                strcat($$.code, end);

              } else {
                yyerror("attempted to retrieve a symbol not in table\n");
                printf("offending symbol: %s\n", $1.strval );
              }

              char end[8];
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              if (verbose) {
                printf("statement -> var := bool_exp ? expression : expression\n");
                printf("%s\n\n", $$.code);
              }
            }
          | IF bool_exp THEN stmt_list ENDIF {
              newlabel($$.begin);
              newlabel($$.after);
              gen2($$.code, ":", $$.begin); // declare label first
              strcat($$.code, $2.code); // add code to compute expression
              char ifthen[64], gotoend[64], end[64];
              gen3(ifthen, "?:=", $4.begin, $2.place); // if true then statementlist
              gen2(gotoend, ":=", $$.after); // else goto end
              strcat($$.code, ifthen); // add the if
              strcat($$.code, gotoend);// add the branch around
              strcat($$.code, $4.code); // add the code for if
              gen2(end, ":", $$.after); // declare ending label and add it
              strcat($$.code, end);

              if (verbose) {
                printf("statement -> if bool_exp then stmt_list endif\n");
                printf("%s\n\n", $$.code);
              }
            }
          | IF bool_exp THEN stmt_list ELSE stmt_list ENDIF {
              newlabel($$.begin); // stick with the convention of begin/place being names
              newlabel($$.after); 
              gen2($$.code, ":", $$.begin); // start with the new label
              strcat($$.code, $2.code); // add code to compute the boolean
              char ifthen[64], elsethen[64], gotoend[64], end[64];
              gen3(ifthen, "?:=", $4.begin, $2.place); // brances
              gen2(elsethen, ":=", $6.begin);
              gen2(gotoend, ":=", $$.after);
              strcat($$.code, ifthen);
              strcat($$.code, elsethen);
              strcat($$.code, $4.code);
              strcat($$.code, gotoend);
              strcat($$.code, $6.code);
              gen2(end, ":", $$.after);
              strcat($$.code, end);

              if (verbose) {
                printf("statement -> if bool_exp then stmt_list else stmt_list endif\n");
                printf("%s\n\n", $$.code);
              }
            }
          | IF bool_exp THEN stmt_list elif_list ENDIF {
              newlabel($$.begin);
              strcpy($$.after, $5.after);
              gen2($$.code, ":", $$.begin); // start with the new label
              strcat($$.code, $2.code); // add code to compute the boolean
              char ifthen[64], gotonext[64], gotoend[64];
              gen3(ifthen, "?:=", $4.begin, $2.place);
              strcat($$.code, ifthen);
              gen2(gotonext, ":=", $5.begin);
              strcat($$.code, gotonext);
              strcat($$.code, $4.code);
              gen2(gotoend, ":=", $$.after);
              strcat($$.code, gotoend);
              strcat($$.code, $5.code);
              if (verbose) {
                printf("statement -> if bool_exp then stmt_list elif_list endif\n");
                printf("%s\n\n", $$.code);
              }
            }
          ;

bool_exp : relation_and_exp {
            strcpy($$.place, $1.place);
            strcpy($$.code, $1.code);
            if (verbose) {
              printf("bool_exp -> relation_and_exp\n");
              printf("%s\n\n", $$.code);
            }
           }
         | bool_exp OR relation_and_exp {
            newtemp($$.place);
            char quad[16];
            gen4(quad, "||", $$.place, $1.place, $3.place);
            strcpy($$.code, $1.code);
            strcat($$.code, $3.code);
            strcat($$.code, quad);
            if (verbose) {
              printf("bool_exp -> bool_exp OR relation_and_exp\n");
              printf("%s\n\n", $$.code);
            }
           }
         ;

relation_and_exp : relation_exp {
                    strcpy($$.place, $1.place);
                    strcpy($$.code, $1.code);
                    if (verbose) {
                      printf("relation_and_exp -> relation_exp\n");
                      printf("%s\n\n", $$.code);
                    }
                   }
                 | relation_and_exp AND relation_exp {
                    newtemp($$.place);
                    char quad[16];
                    gen4(quad, "&&", $$.place, $1.place, $3.place);
                    strcpy($$.code, $1.code);
                    strcat($$.code, $3.code);
                    strcat($$.code, quad);

                    if (verbose) {
                      printf("relation_and_exp -> relation_and_exp AND relation_exp\n");
                      printf("%s\n\n", $$.code);
                    }
                   }
                 ;

relation_expA : expression comp expression {
                  newtemp($$.place);
                  char quad[16];
                  gen4(quad, $2, $$.place, $1.place, $3.place);
                  strcpy($$.code, $1.code);
                  strcat($$.code, $3.code);
                  strcat($$.code, quad);

                  if (verbose) {
                    printf("relation_exp' -> expression comp expression\n");
                    printf("%s\n\n", $$.code);
                  }
                }
              | TRUE {
                  newtemp($$.place);
                  gen3i($$.code, "=", $$.place, 1);
                  if (verbose) {
                    printf("relation_exp' -> TRUE\n");
                    printf("%s\n\n", $$.code);
                  }
                }
              | FALSE { 
                newtemp($$.place);
                gen3i($$.code, "=", $$.place, 0);
                if (verbose) {
                  printf("relation_exp' -> FALSE\n");
                  printf("%s\n\n", $$.code);
                }
              }
              | L_PAREN bool_exp R_PAREN { 
                  strcpy($$.place, $2.place);
                  strcpy($$.code, $2.code);
                  if (verbose) {
                    printf("relation_exp' -> (bool_exp)\n");
                    printf("%s\n\n", $$.code);
                  }
                }
              ;

relation_exp : NOT relation_expA { 
                strcpy($$.place, $2.place);
                strcpy($$.code, $2.code);
                char signswitch[16];
                gen3(signswitch, "!", $$.place, $$.place);
                strcat($$.code, signswitch);
                
                if (verbose) {
                  printf("relation_exp -> not relation_exp'\n");
                  printf("%s\n\n", $$.code);
                }
               }
             | relation_expA {
                strcpy($$.place, $1.place);
                strcpy($$.code, $1.code);
                if (verbose) {
                  printf("relation_exp -> relation_exp'\n");
                  printf("%s\n\n", $$.code);
                }
               }
             ;

comp : EQ  {
        strcpy($$, "=="); 
        if (verbose) {
          printf("comp -> ==\n");
          printf("%s\n\n", $$);
        }
       }
     | NEQ {
        strcpy($$, "!="); 
        if (verbose) {
          printf("comp -> <>\n");
          printf("%s\n\n", $$);
        }
       }
     | LTE {
        strcpy($$, "<="); 
        if (verbose) {
          printf("comp -> <=\n");
          printf("%s\n\n", $$);
        }
       }
     | GTE {
        strcpy($$, ">="); 
        if (verbose) {
          printf("comp -> >=\n");
          printf("%s\n\n", $$);
        }
       }
     | LT  {
        strcpy($$, "<"); 
        if (verbose) {
          printf("comp-> < \n");
          printf("%s\n\n", $$);
        }
       }
     | GT  {
        strcpy($$, ">"); 
        if (verbose) {
          printf("comp-> > \n");
          printf("%s\n\n", $$);
        }
       }
     ;

m_exp : term { 
          strcpy($$.place, $1.place);
          strcpy($$.code, $1.code);
          if (verbose) {
            printf("multiplicative_exp -> term\n");
            printf("%s\n\n", $$.code);
          }
        }
      | m_exp MULT term { 
          newtemp($$.place);
          char quad[16];
          gen4(quad, "*", $$.place, $1.place, $3.place);
          strcpy($$.code, $1.code);
          strcat($$.code, $3.code);
          strcat($$.code, quad);

          if (verbose) {
            printf("multiplicative_exp -> multiplicative_exp * term\n");
            printf("%s\n\n", $$.code);
          }
        }
      | m_exp DIV term { 
          newtemp($$.place);
          char quad[16];
          gen4(quad, "/", $$.place, $1.place, $3.place);
          strcpy($$.code, $1.code);
          strcat($$.code, $3.code);
          strcat($$.code, quad);
          
          if (verbose) {
            printf("multiplicative_exp -> multiplicative_exp / term\n");
            printf("%s\n\n", $$.code);
          }
        }
      | m_exp MOD term { 
          newtemp($$.place);
          char quad[16];
          gen4(quad, "%", $$.place, $1.place, $3.place);
          strcpy($$.code, $1.code);
          strcat($$.code, $3.code);
          strcat($$.code, quad);
          if (verbose) {
            printf("multiplicative_exp -> multiplicative_exp modulo term\n");
            printf("%s\n\n", $$.code);
          }
        }
      ;

expression : m_exp { 
              strcpy($$.place, $1.place);
              strcpy($$.code, $1.code);
              if (verbose) {printf("expression -> multiplicative_exp\n");}
             }
           | expression ADD m_exp {
              newtemp($$.place);
              char quad[16];
              gen4(quad, "+", $$.place, $1.place, $3.place); 
              strcpy($$.code, $1.code);
              strcat($$.code, $3.code);
              strcat($$.code, quad);
              
              if (verbose) {
                printf("expression -> expression + multiplicative_exp\n");
                printf("%s\n\n", $$.code);
              }
             }
           | expression SUB m_exp {
                newtemp($$.place);
                char quad[16];
                gen4(quad, "-", $$.place, $1.place, $3.place); 
                strcpy($$.code, $1.code);
                strcat($$.code, $3.code);
                strcat($$.code, quad);
                
                if (verbose) {
                  printf("expression -> expression - multiplicative_exp\n");
                  printf("%s\n\n", $$.code);
                }
             }
           ;


var : IDENT L_BRACKET expression R_BRACKET {
        // name and type will already be in symtab, pass (name,index) along as string
        sprintf($$.strval, "%s,%s", $1, $3.place); // id, index
        strcpy($$.code, $3.code);
        
        if (verbose) {
          printf("var -> ident[expression]\n");
          printf("%s\n\n",$$);
        }
      }

    | IDENT {
        // name and type will already be in symtab, pass name along
        strcpy($$.strval, $1);
        strcpy($$.code, "");
        if (verbose) {
          printf("var -> ident %s\n", $1);
          printf("%s\n\n",$$); // id
        } 
      }
    ;

term : SUB termA {
          strcpy($$.place, $2.place);
          // code to calculate the term plus `concat` sign switch
          strcpy($$.code, $2.code);
          char signswitch[16];
          gen4i(signswitch, "*", $$.place, $$.place, -1);
          strcat($$.code, signswitch);

          if (verbose) {
            printf("term -> SUB term'\n");
            printf("%s\n\n", $$.code);
          }
       }
     | termA {
          strcpy($$.place, $1.place);
          strcpy($$.code, $1.code);
          
          if (verbose) {
            printf("term -> term'\n");
            printf("%s\n\n", $$.code);
          }
       }
     ;

termA : var { // when var becomes a term, we only want the value currently in it
          int index = symtab_get($1.strval);
          // handle both the int and array cases
          if (index >= 0) {
            if (symtab_entry_is_int(index)) {
              // avoid making new temp since variable already declared
              strcpy($$.place,$1.strval);
              strcpy($$.code,"");
            } else {
              // newtemp to extract value at index
              newtemp($$.place);
              gen3($$.code, "=[]", $$.place, $1.strval ); // $1 has "name,index"
            }
          } else {
            yyerror("attempted to retrieve a symbol not in table\n");
            printf("offending symbol: %s\n", $1.strval);
          }

          if (verbose) {
            printf("term' -> var \n");
            printf("%s\n\n", $$.code);
          }
        }

      | NUMBER {
          int imm = $1;
          newtemp($$.place);
          gen3i($$.code, "=", $$.place, imm);
          
          if (verbose) {
            printf("term' -> NUMBER \n");
            printf("%s\n\n", $$.code);
          }
        }
      | L_PAREN expression R_PAREN {
          strcpy($$.place, $2.place);
          strcpy($$.code,$2.code);
          if (verbose) {
            printf("term' -> (expression)\n\n");
            printf("%s\n\n", $$.code);
          }
        }
      ;
%%

int main (const int argc, const char** argv) {  
  if (argc > 1) {
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
      printf("Could not locate file: %s\n", argv[0]);
      exit(1);
    }
  }
  
  symtab_init();
  yyparse(); // completed code resides in array 'program'


  if (errcount == 0) {
    char outname[32];
    int dot_loc = strcspn(argv[1], ".");
    snprintf(outname, dot_loc+1, "%s", argv[1]);
    strcat(outname, ".mil");
    printf("%s\n", outname);
    
    yyout = fopen(outname, "w");    
    
    if (yyout == NULL) {
      printf("File Output Failed\n");
      fclose(yyout);
      exit(1);
    }
    
    fprintf(yyout, "%s\n", program);  
    fclose(yyout);
  }
  
  
  
  return 0; 
}

void yyerror(const char* msg) {
    printf("** Line %d, position %d: %s\n", yylineno, yycolumno, msg);  
    ++errcount;
}
