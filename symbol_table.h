#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

struct symbol {
    char name[64];
    int type; // 0 for int, 1 for array
    int istemp;
};

struct symbol_table {
    struct symbol st[1024];
    int length;
    int initialized;
} symtab;


void symtab_init(){
    symtab.length = 0;
    symtab.initialized = 1;
}


// returns index of matching symbol, 0 if not found
int symtab_get(char* key) { 
    if (symtab.initialized) {
        int length = symtab.length;
        int i = 0;

        char buff[32];
        int comma_loc = strcspn(key, ",");

        snprintf(buff, comma_loc+1, "%s", key); // copy up to the comma
        //printf("buff: %s\n", buff);

        while ( i < length) {
            if (!strcmp(buff,symtab.st[i].name)) { // if name found
                return i;
            }
            ++i;
        }
    } else {
        printf("symbol table uninitialized\n");
        exit(1);
    }

    return -1;
}


// returns type of symtab entry specified by key, or -1 if not present
int symtab_entry_is_int(int index) { 
    return (symtab.st[index].type == 0);
}


// insert functions will increment the length of the symbol table if not present
// return with error code if append attempted

int symtab_put(char* name, int type, int istemp) {
    if (symtab.initialized) {
        
        int index = symtab_get(name);
        int not_present = (index == -1);

        if (not_present) {
            symtab.length++;       
            strcpy(symtab.st[symtab.length-1].name, name);
            symtab.st[symtab.length-1].type = type;
            symtab.st[symtab.length-1].istemp = istemp;
        } else {

            return 1;
        }

    } else {
        printf("symbol table uninitialized\n");
        exit(1);
    }
    return 0;
}

void symtab_dump() {
    int i = 0;
    while (i < symtab.length) {
        printf("Symtab at position %i: %s\n", i, symtab.st[i].name);
        ++i;
    }
}

#endif
