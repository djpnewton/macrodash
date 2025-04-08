#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "Do you want to deploy locally or remotely? (local/remote)"
read -r DEPLOY_TYPE

if [ "$DEPLOY_TYPE" == "local" ]; then
  echo "Building and deploying locally..."
  echo "FRED API KEY: $FRED_API_KEY"
  dart_frog build
  dart build/bin/server.dart
elif [ "$DEPLOY_TYPE" == "remote" ]; then
  echo "Building and deploying remotely..."
  dart_frog build
  cd build && flyctl deploy
else
  echo "Invalid option. Please choose 'local' or 'remote'."
  exit 1
fi