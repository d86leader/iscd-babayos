#!/bin/bash

outfile=$1
shift 1

let seekam=0

for infile in $@; do
	dd if=$infile of=$outfile bs=1 count=512 conv=notrunc oflag=seek_bytes seek=$seekam
	let "seekam = $seekam + 512"
done
