#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

function usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] CLIENT_LIB_NAME [GENERATOR_NAME]

Sync generated client library code into the corresponding repository folder.

This script must be run from the root of the target client library repository
(e.g. from inside onfido-python/, onfido-node/, etc.).

Arguments:
  CLIENT_LIB_NAME        The client library identifier (python, node, java, php, ruby)
  GENERATOR_NAME         The generator name used during generation (defaults to CLIENT_LIB_NAME)
                         Examples: python/urllib3, python/asyncio, typescript-axios

Environment variables:
  ONFIDO_OPENAPI_SPEC_FOLDER   Path to the openapi-spec repo (default: ../onfido-openapi-spec)

Examples:
  # From inside onfido-python/:
  ../onfido-openapi-spec/shell/$(basename "$0") python python/urllib3

  # From inside onfido-node/:
  ../onfido-openapi-spec/shell/$(basename "$0") node typescript-axios

  # From inside onfido-java/:
  ../onfido-openapi-spec/shell/$(basename "$0") java

  # From inside onfido-php/:
  ../onfido-openapi-spec/shell/$(basename "$0") php

  # From inside onfido-ruby/:
  ../onfido-openapi-spec/shell/$(basename "$0") ruby
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [ $# -lt 1 ];
then
  usage
  exit 1
fi

ONFIDO_OPENAPI_SPEC_FOLDER=${ONFIDO_OPENAPI_SPEC_FOLDER:-../onfido-openapi-spec}

client_lib_name=$1
generator_name=${2:-$client_lib_name}

# Sanity check
if [ "$(grep -ie "^# Onfido $client_lib_name.* Library" README.md)" = "" ];
then
  echo "This doesn't look to be a valid onfido-$client_lib_name folder"
  exit 2
fi

if [[ "$OSTYPE" = "darwin"* ]]; then
  # Mac OSX
  SED_OPTS="-i -E"
else
  # Linux
  SED_OPTS="-i"
fi

# Sync library contents
rsync -r --exclude='/.git*' --exclude='/CHANGELOG.md' --exclude='/MIGRATION.md' --exclude='/.release.json' \
  --exclude='/.openapi-generator-ignore' --exclude='/.openapi-generator/FILES' \
  --exclude-from=${ONFIDO_OPENAPI_SPEC_FOLDER}/generators/${generator_name}/exclusions.txt \
  --delete-after ${ONFIDO_OPENAPI_SPEC_FOLDER}/generated/artifacts/${generator_name}/ .

# Run specific pre-commit commands
case $client_lib_name in

  java)
    sed $SED_OPTS 's/ *$//' pom.xml
    mvn -B package --file pom.xml clean -Dmaven.test.skip
  ;;

  node)
    # workaround typeMappings setting not working with typescript-node generator
    sed $SED_OPTS 's/\([ <{]\)File\([>},]\)/\1FileTransfer\2/g' api.ts
    npx prettier --write package.json
    npm install
  ;;

  php)
    sed $SED_OPTS "s/ *$//" composer.json
    composer update --lock
  ;;

  python)
    sed $SED_OPTS "s/ *$//" pyproject.toml setup.py
    sed $SED_OPTS 's/output: Optional\[Dict\[str, Any\]\]/output: Any/g' \
      onfido/models/webhook_event_payload_resource.py \
      onfido/models/task.py
    pipx run poetry==2.2 lock
  ;;

  ruby)
    sed $SED_OPTS "s/ *$//" Gemfile
    bundle lock --update
  ;;

esac

# Run linter on generated .md files
npx prettier --write *.md
