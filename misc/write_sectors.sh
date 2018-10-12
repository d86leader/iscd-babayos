#!/bin/bash

outfile=$1
shift 1

let seekam=0

for infile in $@; do
	echo "writing ${infile} to ${outfile} at offset ${seekam}"
	dd if=$infile of=$outfile bs=1 count=512 conv=notrunc oflag=seek_bytes seek=$seekam >/dev/null 2>/dev/null
	let "seekam = $seekam + 512"
done
