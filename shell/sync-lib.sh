#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

if [ $# -lt 1 ];
then
  echo "Usage: $0 client-lib-name [generator-name]"
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
    pipx run poetry==1.8 lock
  ;;

  ruby)
    sed $SED_OPTS "s/ *$//" Gemfile
    bundle lock --update
  ;;

esac

# Run linter on generated .md files
npx prettier --write *.md
