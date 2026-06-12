#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
export NODE_USE_ENV_PROXY="${NODE_USE_ENV_PROXY:-1}"
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7897}"
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7897}"
"${NODE_BIN:-/Applications/Codex.app/Contents/Resources/cua_node/bin/node}" server/server.mjs
