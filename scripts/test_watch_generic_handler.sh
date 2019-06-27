#!/usr/bin/env bash

# Te script expects a log file passed as an argument and will read the output for the watch and print that in the log file

#echo $1

read a

echo `date '+%Y-%m-%d_%H:%M:%S'` - $a >> $1

set +x
