#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

struct symbol {
    char name[64];
    int type; // 0 for int, 1 for array
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
        while ( i < length) {
            if (!strcmp(key,symtab.st[i].name)) { // if name found
                return i;
            }
            ++i;
        }
    } else {
        printf("symbol table uninitialized\n");
        exit(1);
    }

    return 0;
}


// returns type of symtab entry specified by key, or -1 if not present
int symtab_entry_is_int(int index) { 
    return symtab.st[index].type;
}


// insert functions will increment the length of the symbol table if not present
// and will append at the original location if it is

void symtab_put(char* name, int type ) {
    if (symtab.initialized) {
        
        int index = symtab_get(name);
        int not_present = !index;

        if (not_present) {
            symtab.length++;       
            strcpy(symtab.st[symtab.length].name, name);
            symtab.st[symtab.length].type = type;


        } else {
            strcpy(symtab.st[index].name, name);
            symtab.st[index].type = type;
        }

    } else {
        printf("symbol table uninitialized\n");
        exit(1);
    }
}

// should just insert a single int at a single array index, will be called inside for loops


#endif
