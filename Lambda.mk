all: deps build

CURRENT_DIR = $(notdir $(shell pwd))

FUNCTION ?= $(CURRENT_DIR)
FUNCTION_SOURCE  ?= $(FUNCTION).go
FUNCTION_BINARY  ?= $(FUNCTION)
FUNCTION_PACKAGE ?= $(FUNCTION).zip

DOCKER_NETWORK ?= localstack_default
DOCKER_NETWORK_OPTIONS = --docker-network $(DOCKER_NETWORK)
TEMPLATE_FILE ?= ../template.yaml
TEMPLATE_OPTIONS = -t $(TEMPLATE_FILE)


GO_FILES = $$(go list ./... | grep -v /vendor/)

ifdef CHANGE
BENCHMARK_LOG=benchmark_change.log
else
BENCHMARK_LOG=benchmark_master.log
endif

DEPS = \
        github.com/golang/dep/cmd/dep \
        github.com/kisielk/errcheck \
        github.com/uber/go-torch \
        golang.org/x/perf/cmd/benchstat

tool-deps: ## Install tools deps
	go get $(DEPS)

tool-deps-up: ## Update tools deps
	go get -u $(DEPS)

setup: tool-deps
	dep init || true

deps: setup ## Install deps to vendor
	dep ensure

deps-up: ## Update deps
	dep ensure -update

test: ## Test
	go test -race -cpu 1,2,4 $(GO_FILES)

test-bench: ## Test with Benchmarking
	go test -race -cpu 1,2,4 -count 5 -benchmem -bench $(GO_FILES) | tee -a $(BENCHMARK_LOG)

stats: ## Benchmark statistics
	benchstat benchmark_master.log benchmark_change.log

build: clean # Build the Go
	GOOS=linux go build $(FUNCTION_SOURCE)
	zip $(FUNCTION_PACKAGE) ./$(FUNCTION_BINARY)

invoke: build ## Invoke function locally
	sam local invoke $(FUNCTION) $(DOCKER_NETWORK_OPTIONS) $(TEMPLATE_OPTIONS)

clean: ## Clean up
	@rm -f $(FUNCTION_BINARY)
	@rm -f $(FUNCTION_PACKAGE)


define print_help_for
    grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(1) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-20s\033[0m%s\n", $$1, $$2}'
endef

help: ## Show Help
	@printf "\033[31mLambda: $(FUNCTION)\033[0m\n"
	@printf "\033[36mHelp: \033[0m\n"
	@$(foreach make,$(MAKEFILE_LIST),$(call print_help_for,$(make));)
	@printf "\n"

.PHONY: all setup deps dep depup test test-bench help