#!/usr/bin/env bash

set -ex

HERE=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

STAGE=${STAGE:-production}

PIPARGS=""
if [ "$1" == "--user" ]; then
  PIPARGS="${PIPARGS} --user"
fi

AODNFETCHER_URL="git+https://github.com/aodn/python-aodnfetcher.git@master"
CC_PLUGIN_IMOS_URL="s3prefix://imos-artifacts/promoted/cc-plugin-imos/${STAGE}?pattern=^.*.whl$"

WHEEL_CACHE_DIR=${HERE}/.python-aodndata-download-cache

echo "##### Installing dependencies into virtual environment #####"
pip install ${PIPARGS} ${AODNFETCHER_URL}
pip install ${PIPARGS} $(aodnfetcher -c ${WHEEL_CACHE_DIR} ${CC_PLUGIN_IMOS_URL} \
    | python -c "import json, sys; print(json.load(sys.stdin)['${CC_PLUGIN_IMOS_URL}']['local_file'])")

pip install ${PIPARGS} -r requirements.txt
