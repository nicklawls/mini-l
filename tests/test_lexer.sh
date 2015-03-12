#!/bin/bash
cat tests/dowhiletest.min | lexer | diff samples/dowhiletest.tokens -;
cat tests/mytest.min | lexer | diff samples/mytest.tokens -;
cat tests/ifelseiftest.min | lexer | diff samples/ifelseiftest.tokens -;
cat tests/primes.min | lexer | diff samples/primes.tokens -;
