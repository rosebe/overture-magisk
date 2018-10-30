.PHONY : all clean

CC     ?= gcc
STRIP  ?= strip
OUTPUT ?= ./dns_keeper

all: ${OUTPUT}

${OUTPUT} : main.c
	${CC} -ldl main.c -o ${OUTPUT}
	${STRIP} ${OUTPUT}

clean : 
	rm ${OUTPUT}

