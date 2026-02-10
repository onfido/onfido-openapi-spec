#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

COMMON_CONFIG_FILE="generators/common/config.yaml"
GENERATORS=${*:-`find generators -name 'config.yaml' -exec dirname {} \; | sed 's/generators\///'`}
GENERATED_CONFIG_FILES=""

OPENAPI_GENERATOR_VERSION=${OPENAPI_GENERATOR_VERSION:-v7.13.0}
OPENAPI_GENERATOR_COMMAND=${OPENAPI_GENERATOR_COMMAND:-\
  docker run --rm -v "$(pwd):/local" -w /local \
  openapitools/openapi-generator-cli:${OPENAPI_GENERATOR_VERSION}}

BUMP_CLIENT_LIBRARY_VERSION=${BUMP_CLIENT_LIBRARY_VERSION:-""}
CLIENT_LIBRARY_VERSION_SUFFIX=${CLIENT_LIBRARY_VERSION_SUFFIX:-""}
OVERRIDE_CLIENT_LIBRARY_VERSION=${OVERRIDE_CLIENT_LIBRARY_VERSION:-""}

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

  echo -n "${CLIENT_LIBRARY_VERSION_SUFFIX}"
}

function validate_templates_checksum() {
  OVERRIDE_COMMAND=""
  GENERATOR_NAME=$1
  LIBRARY_NAME=$2
  LIBRARY=""
  RESULT=0

  if [ ! -z "$LIBRARY_NAME" ];
  then
    LIBRARY="--library $LIBRARY_NAME"
  fi

  $OPENAPI_GENERATOR_COMMAND author template -g $GENERATOR_NAME $LIBRARY -o generated/templates/${GENERATOR} > /dev/null

  GENERATORS_PATH=$(pwd)/generators/${GENERATOR}/templates
  GENERATED_PATH=$(pwd)/generated/templates/${GENERATOR}

  pushd $GENERATED_PATH > /dev/null
  shasum -a 256 $(find . -type f) >| SHA256SUM
  popd > /dev/null

  pushd $GENERATORS_PATH > /dev/null
  echo >| SHA256SUM.new

  for FILENAME in $(find . -type f \! -name  'SHA256SUM*' | sort);
  do
    LIB_SHASUM=$(grep \\$FILENAME ${GENERATED_PATH}/SHA256SUM | awk '{print $1}' || true)
    OUR_SHASUM=$(grep \\$FILENAME ${GENERATORS_PATH}/SHA256SUM | awk '{print $1}' || true)

    if [[ ! -z "$LIB_SHASUM" ]];  # File is provided by lib
    then
      if [ ! -z "$OUR_SHASUM" ] && [[ "$LIB_SHASUM" != "$OUR_SHASUM" ]];   # We do have checksum and doesn't match
      then
        LIBRARY_TEMPLATE="generated/templates/${GENERATOR}/$(echo $FILENAME | sed 's/^\.\///')"
        TEMPLATE_SUBPATH="$(dirname $FILENAME/ | sed -E 's/^\.\/?//' )"
        OVERRIDE_COMMAND="${OVERRIDE_COMMAND}\n\tcp ${LIBRARY_TEMPLATE} generators/${GENERATOR}/templates/${TEMPLATE_SUBPATH}"
        RESULT=1
      fi

      echo "$LIB_SHASUM  $FILENAME" >> ${GENERATORS_PATH}/SHA256SUM.new
    fi
  done

  popd > /dev/null

  # Remove if empty or rename otherwise
  if [[ "$(grep -e '\s' ${GENERATORS_PATH}/SHA256SUM.new)" == "" ]];
  then
    unlink ${GENERATORS_PATH}/SHA256SUM.new
  else
    mv ${GENERATORS_PATH}/SHA256SUM.new ${GENERATORS_PATH}/SHA256SUM
  fi

  if [ "$RESULT" -ne "0" ];
  then
    echo -e "\n################################################################################\n"
    echo -e "ERROR while building generator ${GENERATOR}: SHA256SUM for template(s) changed with OpenAPI generator ${OPENAPI_GENERATOR_VERSION}!\n"
    echo -e "Please overwrite the template(s) and carefully check what has changed by running:\n${OVERRIDE_COMMAND}\n"
    echo -e "\tgit add -p generators/${GENERATOR}/templates/\n"
  fi

  return $RESULT
}

cd ${BASEDIR}
rm -rf generated; mkdir -p generated/configuration

for GENERATOR in $GENERATORS
do
  if [ "${GENERATOR}" != "common" ];
  then
    echo "Building configuration for generator ${GENERATOR}..."

    read GENERATOR_NAME GENERATOR_LIBRARY <<<$(IFS="/"; echo $GENERATOR)

    GENERATOR_FOLDER=generators/${GENERATOR}
    CONFIG_FILE=${GENERATOR_FOLDER}/config.yaml
    GENERATED_CONFIG_FILE=generated/configuration/${GENERATOR}.yaml

    GIT_REPO_ID=$(grep gitRepoId: $CONFIG_FILE | sed 's/gitRepoId: //g')
    LIBRARY=$(grep library: $CONFIG_FILE | sed 's/library: //g')

    if [ -z "${OVERRIDE_CLIENT_LIBRARY_VERSION}" ] && [ -n "${GIT_REPO_ID}" ];
    then
      LATEST_LIBRARY_VERSION=$(curl -s https://api.github.com/repos/onfido/${GIT_REPO_ID}/releases | jq '.[0].name' | sed 's/[v"]//g')

      if [ "$LATEST_LIBRARY_VERSION" == null ];
      then
        LATEST_LIBRARY_VERSION="0.0.0"
      fi

      CURRENT_LIBRARY_VERSION=$(semver_bump ${LATEST_LIBRARY_VERSION} ${BUMP_CLIENT_LIBRARY_VERSION})

      echo "Latest delivered version was: ${LATEST_LIBRARY_VERSION}"
      echo "Current version is going to be: ${CURRENT_LIBRARY_VERSION}"
      echo "Client library version bump?: ${BUMP_CLIENT_LIBRARY_VERSION}"
    else
      CURRENT_LIBRARY_VERSION=$OVERRIDE_CLIENT_LIBRARY_VERSION
    fi

    validate_templates_checksum $GENERATOR_NAME $LIBRARY_NAME

    mkdir -p $(dirname $GENERATED_CONFIG_FILE)

    ( cat $COMMON_CONFIG_FILE && echo && cat $CONFIG_FILE ) | \
        GENERATOR=${GENERATOR} \
        GENERATOR_NAME=${GENERATOR_NAME} \
        GENERATOR_LIBRARY=${GENERATOR_LIBRARY} \
        CLIENT_LIBRARY_VERSION=${CURRENT_LIBRARY_VERSION} \
        envsubst >| ${GENERATED_CONFIG_FILE}

    echo "Configuration for generator ${GENERATOR} built."

    # Dump version number aside to have github action retrieving them later on
    if [ -n "${GITHUB_OUTPUT}" -a -n "${CURRENT_LIBRARY_VERSION}" ];
    then
      echo "$(echo $GENERATOR | tr /- _ )_version=${CURRENT_LIBRARY_VERSION}" >> $GITHUB_OUTPUT
    fi

    GENERATED_CONFIG_FILES="${GENERATED_CONFIG_FILES} ${GENERATED_CONFIG_FILE}"
  fi
done

${OPENAPI_GENERATOR_COMMAND} batch --clean ${GENERATED_CONFIG_FILES}
