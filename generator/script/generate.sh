#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/../..

CONFIG_FILES=${*:-`ls generator/configuration/*.yaml`}
GENERATED_CONFIG_FILES=""

OPENAPI_GENERATOR_COMMAND=${OPENAPI_GENERATOR_COMMAND:-\
  docker run --rm -v "$(pwd):/local" -w /local \
  openapitools/openapi-generator-cli:v7.3.0}

cd ${BASEDIR}
rm -rf generated; mkdir -p generated/configuration

for CONFIG_FILE in $CONFIG_FILES
do
  GENERATOR=$(basename $CONFIG_FILE .yaml)

  if [ "${GENERATOR}" != "common" ];
  then
    GENERATED_CONFIG_FILE=generated/configuration/${GENERATOR}.yaml

    ( cat generator/configuration/common.yaml && echo &&
      cat generator/configuration/${GENERATOR}.yaml ) | \
        GENERATOR=${GENERATOR} envsubst >| \
        ${GENERATED_CONFIG_FILE}

    echo "Configuration for generator ${GENERATOR} built."

    GENERATED_CONFIG_FILES="${GENERATED_CONFIG_FILES} ${GENERATED_CONFIG_FILE}"
  fi
done

${OPENAPI_GENERATOR_COMMAND} batch --clean ${GENERATED_CONFIG_FILES}
