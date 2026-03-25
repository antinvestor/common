SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all

BIN := $(abspath .tmp/bin)
GO  ?= go

export PATH  := $(BIN):$(PATH)
export GOBIN := $(BIN)

$(BIN)/buf:
	@mkdir -p $(BIN) && $(GO) install github.com/bufbuild/buf/cmd/buf@latest

$(BIN)/golangci-lint:
	@mkdir -p $(BIN) && $(GO) install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

.PHONY: proto-lint
proto-lint: $(BIN)/buf
	cd proto && buf format -w && buf lint

.PHONY: proto-push
proto-push: $(BIN)/buf
	cd proto && buf push

.PHONY: build
build:
	$(GO) build ./...

.PHONY: build-tools
build-tools:
	cd tools/inject-permissions && $(GO) build .
	cd tools/generate-opl && $(GO) build .

.PHONY: test
test:
	$(GO) test -race -cover ./...

.PHONY: lint
lint: $(BIN)/golangci-lint
	$(GO) vet ./... && golangci-lint run

.PHONY: tidy
tidy:
	$(GO) mod tidy
	cd tools/inject-permissions && $(GO) mod tidy
	cd tools/generate-opl && $(GO) mod tidy

.PHONY: all
all: proto-lint build build-tools test lint

.PHONY: clean
clean:
	rm -rf $(BIN) tools/inject-permissions/inject-permissions tools/generate-opl/generate-opl

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "%-20s %s\n",$$1,$$2}'
