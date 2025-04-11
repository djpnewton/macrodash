#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Check if a deployment type is provided as an argument
if [ $# -eq 0 ]; then
  echo "Usage: $0 <local|remote> [debug|release]"
  exit 1
fi

DEPLOY_TYPE=$1
BUILD_MODE=${2:-release} # Default to 'release' if no second argument is provided

if [ "$DEPLOY_TYPE" == "local" ]; then
  echo "Building and deploying locally..."
  echo "Build mode: $BUILD_MODE"
  echo "FRED API KEY: $FRED_API_KEY"

  if [ "$BUILD_MODE" == "debug" ]; then
    dart_frog dev
  elif [ "$BUILD_MODE" == "release" ]; then
    dart_frog build
    dart build/bin/server.dart
  else
    echo "Invalid build mode. Please choose 'debug' or 'release'."
    exit 1
  fi

elif [ "$DEPLOY_TYPE" == "remote" ]; then
  if [ "$BUILD_MODE" != "release" ]; then
    echo "Remote deployment can only be done in 'release' mode."
    exit 1
  fi

  echo "Building and deploying remotely in release mode..."
  dart_frog build
  cd build && flyctl deploy
else
  echo "Invalid option. Please choose 'local' or 'remote'."
  exit 1
fi