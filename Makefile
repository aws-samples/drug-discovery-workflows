.PHONY: lint

# Define the default workflow name as empty
WORKFLOW_NAME ?=

# Get all workflow directories
WORKFLOW_DIRS := $(wildcard workflows/*)

# Define the lint target
lint:
ifeq ($(WORKFLOW_NAME),)
	@echo "Running Nextflow pipeline with -stub-run for all workflows"
	@for dir in $(WORKFLOW_DIRS); do \
		if [ -f $$dir/main.nf ]; then \
			echo "Running workflow: $$dir"; \
			nextflow -log /dev/null run $$dir/main.nf -stub-run; \
			npm-groovy-lint workflows/$(WORKFLOW_NAME)/main.nf \
		else \
			echo "No main.nf found in $$dir, skipping..."; \
		fi \
	done
else
	@echo "Running Nextflow pipeline with -stub-run for workflow: $(WORKFLOW_NAME)"
	nextflow -log /dev/null run workflows/$(WORKFLOW_NAME)/main.nf -stub-run
	npm-groovy-lint workflows/$(WORKFLOW_NAME)/main.nf
endif
