#!/bin/sh
# Starts the helloworld test server of grpc-go on localhost:50051, called by FloconGrpcDemo.
# Needs Go: brew install go
set -e
cd "$(dirname "$0")"
if [ ! -d grpc-go ]; then
  git clone --depth 1 https://github.com/grpc/grpc-go.git
fi
cd grpc-go/examples/helloworld
go run greeter_server/main.go
