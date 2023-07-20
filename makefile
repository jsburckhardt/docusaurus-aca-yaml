ifdef RELEASE
	DOCS_VERSION := $(RELEASE)
else
	DOCS_VERSION := local
endif

ifdef ACR
	REPO := $(ACR).azurecr.io/
else
	REPO :=
endif

SHELL := /bin/bash

lint:
	npx markdownlint "src/docusaurus/docs/**/*.md"
	npx markdownlint "README.md"

spellcheck:
	npx cspell "src/docusaurus/docs/**/*.md"
	npx cspell README.md

fix-lint:
	@npx markdownlint --fix "src/docusaurus/docs/**/*.md"
	@npx markdownlint --fix "README.md"

package:
	docker build \
		-t docusaurus:$(DOCS_VERSION) \
		-f ./ci/Dockerfile\
		./src/docusaurus

package-tag:
	docker tag docusaurus:$(DOCS_VERSION) $(REPO)docusaurus:$(DOCS_VERSION)
	docker tag docusaurus:$(DOCS_VERSION) $(REPO)docusaurus:latest



package-push:
	export ACR=$$(az deployment sub show -n docusaurus-aca-yaml --query 'properties.outputs.containerRegistryName.value' -o tsv) \
    az acr login -n $$(ACR)
	docker push $(REPO)docusaurus:$(DOCS_VERSION)
	docker push $(REPO)docusaurus:latest

ci-package: package package-tag package-push

.ONESHELL:

dev:
	cd src/docusaurus
	npx docusaurus start

bootstrap:
	az deployment sub create --name docusaurus-aca-yaml --template-file infra/main.bicep --parameters infra/main.parameters.json --location australiaeast

prepare-template:
	source ./ci/prepare_template.sh

deploy:
	export RG=$$(az deployment sub show -n docusaurus-aca-yaml --query 'properties.outputs.resourceGroupName.value' -o tsv); \
	az containerapp create -n "docusaurus" -g $${RG} --yaml ci/deployment.yaml
