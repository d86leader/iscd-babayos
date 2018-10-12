#!/bin/bash
let size=`du -b $1 | cut -f1`
let secs=$size/512+1
echo $secs
