.PHONY: install build test fmt fmt-check clean verify-deployments

FOUNDRY ?= forge

install:
	rm -rf lib/forge-std lib/openzeppelin-contracts
	$(FOUNDRY) install foundry-rs/forge-std@v1.9.6 --no-git
	$(FOUNDRY) install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git

build:
	$(FOUNDRY) build --sizes

test:
	$(FOUNDRY) test -vv

fmt:
	$(FOUNDRY) fmt

fmt-check:
	$(FOUNDRY) fmt --check

clean:
	rm -rf out cache broadcast

verify-deployments:
	./scripts/verify-deployments.sh
