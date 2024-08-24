root_dir := justfile_dir()

default: format check build run

format:
    gleam format
    prettier --write static/*.html
    just --unstable --fmt
    nix fmt

check:
    gleam check

build:
    gleam build

run:
    gleam run

docker-build:
    docker build \
        --platform=linux/amd64 \
        --tag=roc-turtle-editor \
        {{ root_dir }}
    docker tag roc-turtle-editor roc-turtle-editor:latest

docker-run: docker-build
    docker run \
        --platform=linux/amd64 \
        --rm \
        --publish=8000:8000 \
        roc-turtle-editor:latest
