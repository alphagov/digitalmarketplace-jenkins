.DEFAULT_GOAL := help
SHELL := /bin/bash
VIRTUALENV_ROOT := $(shell [ -z ${VIRTUAL_ENV} ] && echo $$(pwd)/venv || echo ${VIRTUAL_ENV})

TAGS ?= all
JOBS ?= '*'

.PHONY: help
help: ## List available commands
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: requirements
requirements: venv ## Install requirements
	${VIRTUALENV_ROOT}/bin/pip install -Ur requirements.txt

.PHONY: venv
venv: ${VIRTUALENV_ROOT}/activate ## Create virtualenv if it does not exist

${VIRTUALENV_ROOT}/activate:
	@[ -z "${VIRTUAL_ENV}" ] && [ ! -d venv ] && virtualenv venv || true

.PHONY: clean
clean: ## Clean workspace (delete all generated files)
	rm -rf venv requirements.txt.md5

.PHONY: jenkins
jenkins: venv ## Run Jenkins playbook
	${DM_CREDENTIALS_REPO}/sops-wrapper -d ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem.enc > ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem
	chmod 600 ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem
	ANSIBLE_CONFIG=playbooks/ansible.cfg ${VIRTUALENV_ROOT}/bin/ansible-playbook \
		-i playbooks/hosts playbooks/jenkins_playbook.yml \
		--private-key ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem \
		-e @<(${DM_CREDENTIALS_REPO}/sops-wrapper -d ${DM_CREDENTIALS_REPO}/jenkins-vars/jenkins.yaml) \
		--tags "${TAGS}" -e "jobs=${JOBS}"
	rm ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem