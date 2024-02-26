#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/../..

CONFIG_FILES=${*:-`ls generator/configuration/*.yaml`}

OPENAPI_GENERATOR_COMMAND=${OPENAPI_GENERATOR:-docker run \
  --rm -v "$(pwd):/local" -w /local \
  openapitools/openapi-generator-cli:v7.3.0}

cd ${BASEDIR}
rm -rf generated; mkdir -p generated/configuration

for CONFIG_FILE in $CONFIG_FILES
do
  GENERATOR=$(basename $CONFIG_FILE .yaml)

  if [ "${GENERATOR}" != "common" ]; then
    ( cat generator/configuration/common.yaml && echo &&
      cat generator/configuration/${GENERATOR}.yaml ) | \
        API_VERSION=1.6.0 GENERATOR=${GENERATOR} envsubst >| \
        generated/configuration/${GENERATOR}.yaml

    echo "Configuration for generator ${GENERATOR} built."
  fi
done

${OPENAPI_GENERATOR_COMMAND} batch --clean --root-dir /local generated/configuration/*.yaml
