#!/bin/bash

# Smoke tests the API server, and if the smoke test fails, removes all build artifacts (yes, this is a bit extreme but was the easiest)
# way to ensure we definitely block corrupted builds

PACKAGE_IDENT=$1

hab pkg install -b core/curl
cd /hab/pkgs/$PACKAGE_IDENT
bin/youtube-dl-server --number-processes 1
sleep 5
curl -i http://localhost:9191/api/play?url=https://www.youtube.com/watch?v=dQw4w9WgXcQ | head -n 1 | grep '302 FOUND' || rm -rf /src/results
