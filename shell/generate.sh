#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

COMMON_CONFIG_FILE="generators/common/config.yaml"
GENERATORS=${*:-`ls generators`}
GENERATED_CONFIG_FILES=""

OPENAPI_GENERATOR_COMMAND=${OPENAPI_GENERATOR_COMMAND:-\
  docker run --rm -v "$(pwd):/local" -w /local \
  openapitools/openapi-generator-cli:v7.3.0}

BUMP_CLIENT_LIBRARY_VERSION=${BUMP_CLIENT_LIBRARY_VERSION:-""}

# $1: version, $2: bump type (Major, Minor, Patch)
function semver_bump() {
  INPUT_VERSION=$1
  BUMP_TYPE=$2
  POS=0
  RESET=
  OUTPUT_VERSION=
  OUTPUT_SEPARATOR="."

  IFS='.' read -ra NUMBERS <<< "$INPUT_VERSION"
  for NUMBER in "${NUMBERS[@]}"; do
    if [ -z "${RESET}" ];
    then
      if ([ $POS -eq 0 ] && [ "$BUMP_TYPE" == "Major" ]) || \
         ([ $POS -eq 1 ] && [ "$BUMP_TYPE" == "Minor" ])   || \
         ([ $POS -eq 2 ] && [ "$BUMP_TYPE" == "Patch" ]) ;
      then
        NUMBER=$((NUMBER+1))
        RESET=1
      fi
    else
      NUMBER=0
    fi

    echo -n "${NUMBER}${OUTPUT_SEPARATOR}"

    if [ $POS -ge 1 ];
    then
      OUTPUT_SEPARATOR=""
    fi

    POS=$((POS+1))
  done
}

cd ${BASEDIR}
rm -rf generated; mkdir -p generated/configuration

for GENERATOR in $GENERATORS
do
  if [ "${GENERATOR}" != "common" ];
  then
    CONFIG_FILE=generators/${GENERATOR}/config.yaml
    echo "Building configuration for generator ${GENERATOR}..."
    GIT_REPO_ID=$(grep gitRepoId: $CONFIG_FILE | sed 's/gitRepoId: //g')

    if [ -n "${GIT_REPO_ID}" ];
    then
      LATEST_LIBRARY_VERSION=$(curl -s https://api.github.com/repos/onfido/${GIT_REPO_ID}/releases/latest | jq .name | sed 's/[v"]//g')
      CURRENT_LIBRARY_VERSION=$(semver_bump ${LATEST_LIBRARY_VERSION} ${BUMP_CLIENT_LIBRARY_VERSION})

      echo "Latest delivered version was: ${LATEST_LIBRARY_VERSION}"
      echo "Current version is going to be: ${CURRENT_LIBRARY_VERSION}"
      echo "Should bump client library?: ${BUMP_CLIENT_LIBRARY_VERSION}"
    else
      CURRENT_LIBRARY_VERSION=""
    fi

    GENERATED_CONFIG_FILE=generated/configuration/${GENERATOR}.yaml

    ( cat $COMMON_CONFIG_FILE && echo && cat $CONFIG_FILE ) | \
        GENERATOR=${GENERATOR} \
        CLIENT_LIBRARY_VERSION=${CURRENT_LIBRARY_VERSION} \
        envsubst >| ${GENERATED_CONFIG_FILE}

    echo "Configuration for generator ${GENERATOR} built."

    # Dump version number aside to have github action retrieving them later on
    if [ -n "${GITHUB_OUTPUT}" -a -n "${CURRENT_LIBRARY_VERSION}" ];
    then
      echo "$(echo $GENERATOR | tr - _ )_version=${CURRENT_LIBRARY_VERSION}" >> $GITHUB_OUTPUT
    fi

    GENERATED_CONFIG_FILES="${GENERATED_CONFIG_FILES} ${GENERATED_CONFIG_FILE}"
  fi
done

${OPENAPI_GENERATOR_COMMAND} batch --clean ${GENERATED_CONFIG_FILES}
