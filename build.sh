#!/bin/sh

gcc -Iinclude -Idependencies src/*.c dependencies/wren.o -lm -o ggwren
