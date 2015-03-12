#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "symbol_table.h"

void gen4(char* buff, char* op, char* dst, char* src1, char* src2) {
    snprintf(buff, 64, "%s %s, %s, %s\n", op, dst, src1, src2);
}

void gen4i(char* buff, char* op, char* dst, char* src1, int imm) {
    snprintf(buff, 64, "%s %s, %s, %i\n", op, dst, src1, imm);
}

void gen3(char* buff, char* op, char* dst, char* src) {
    snprintf(buff, 64, "%s %s, %s\n", op, dst, src);
}

void gen3i(char* buff, char* op, char* dst, int imm) {
    snprintf(buff, 64, "%s %s, %i\n", op, dst, imm);
}

void gen2(char* buff, char* op, char* dst) {
    snprintf(buff, 64, "%s %s\n", op, dst);
}

static int tmpcount = 1;

static int labelcount = 0;

void newtemp(char* dst) {
    
    
    while(symtab_get(dst)) {
        tmpcount++;
        sprintf(dst, "t%i", tmpcount);   
    };
    ++tmpcount; // do the next one for later
    symtab_put(dst, 0); // temps are always int
}

void newlabel(char* dst) {
    sprintf(dst, "L%i", labelcount++);
}
