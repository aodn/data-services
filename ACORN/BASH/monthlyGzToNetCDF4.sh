#!/bin/bash
find . -type f -name '*.gz' -print0 | xargs -0 -I {} nc3gz_to_nc4.sh {}
