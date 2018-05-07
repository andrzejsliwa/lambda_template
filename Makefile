FUNCTIONS = $(sort $(dir $(wildcard */*.go)))

DOCKER_COMPOSE_FILE    = docker-compose-localstack.yml
DOCKER_COMPOSE_OPTIONS = -f $(DOCKER_COMPOSE_FILE)
DOCKER_NETWORK         = localstack_default
DOCKER_NETWORK_OPTIONS = --docker-network $(DOCKER_NETWORK)

define help_entry
    printf "  \033[36mmake %-20s\033[0m%s\n" $(1) $(2)
endef

$(addprefix tool-deps-, $(FUNCTIONS)):
	@make -C $(subst tool-deps-,,$@) tool-deps

$(addprefix deps-, $(FUNCTIONS)):
	@make -C $(subst deps-,,$@) deps

$(addprefix build-, $(FUNCTIONS)):
	@make -C $(subst build-,,$@) build

$(addprefix clean-, $(FUNCTIONS)):
	@make -C $(subst clean-,,$@) clean

$(addprefix test-, $(FUNCTIONS)):
	@make -C $(subst test-,,$@) test

$(addprefix invoke-, $(FUNCTIONS)):
	@make -C $(subst invoke-,,$@) invoke

$(addprefix help-, $(FUNCTIONS)):
	@make -C $(subst help-,,$@) help

tool-deps: $(addprefix tool-deps-, $(FUNCTIONS))
deps: $(addprefix deps-, $(FUNCTIONS))
build: $(addprefix build-, $(FUNCTIONS))
clean: $(addprefix clean-, $(FUNCTIONS))
test: $(addprefix test-, $(FUNCTIONS))

api: build ## Start API locally
	@sam local start-api $(DOCKER_NETWORK_OPTIONS)

local-stack-start: ## Start localstack
	docker-compose $(DOCKER_COMPOSE_OPTIONS) up -d

local-stack-stop: ## Stop localstack
	docker-compose $(DOCKER_COMPOSE_OPTIONS) down

ifeq (generate,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "generate"
  GENERATE_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn argument to starting config
  ifneq ($(GENERATE_ARGS),)
	FUNCTION_NAME := $(firstword $(GENERATE_ARGS))
  endif

  $(eval $(GENERATE_ARGS):;@:)
endif

define generate_function
	mkdir $(1)
	@printf "$(1)/$(1)\n" >> .gitignore
	@printf "include ../Lambda.mk" > $(1)/Makefile
	@cp lambda.template.go $(1)/$(1).go
	@echo "Done."
endef

ifeq ($(GENERATE_ARGS),)
generate: help
else
generate: ## Generate Lambda: make generate FUNCTION_NAME
	@$(call generate_function,$(FUNCTION_NAME))
endif

help: $(addprefix help-, $(FUNCTIONS))
	@printf "\033[31mMain\033[0m\n"
	@printf "\033[36mHelp: \033[0m\n"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-20s\033[0m%s\n", $$1, $$2}'
	@printf "\n"

