#!/bin/bash -e 

if [ "$(git rev-parse qa-test)" != "$(git rev-parse master)" ];  then 
    echo "They're Different. Moving Branch pointer" 
    git update-ref -m "Preping Qa-test"
fi  