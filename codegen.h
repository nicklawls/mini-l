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

int tmpcount = 0;

int labelcount = 0;

void newtemp(char* dst) {
    
    do {
        tmpcount++;
        sprintf(dst, "t%i", tmpcount);
    } while(symtab_get(dst) >= 0); // will repeat if user defined variable collides
    
    symtab_put(dst, 0, 1); // temps are always int
}

void newlabel(char* dst) {
    sprintf(dst, "L%i", labelcount++);
}

void declare_temps(char* head) {
    char declare[32];
    int i = 0;
    while (i < symtab.length) {
        if (symtab.st[i].istemp) {
            gen2(declare, ".", symtab.st[i].name);
            strcat(head, declare);
        }
        ++i;
    }
}
