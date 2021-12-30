#!/bin/bash

# with "--force" to rebuild the project
if [ "$1" = "--force" ]; then
  echo -e "\033[36m force to rebuild... \033[0m"
  rm -rf client/build
  rm -rf server/build
fi

if [ ! -d "client/build" ]; then
  echo -e "\033[36m mkdir client/build... \033[0m"
  mkdir client/build
fi

echo -e "\033[36m build client... \033[0m"
cd client/build; cmake ..; make

cd ../..

if [ ! -d "./server/build" ]; then
  echo -e "\033[36m mkdir server/build... \033[0m"
  mkdir server/build
fi

echo -e "\033[36m build server... \033[0m"
cd server/build; cmake ..; make