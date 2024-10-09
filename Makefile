.PHONY: lint

current_dir = $(shell pwd)

lint:
	docker run --platform linux/amd64 -v ${current_dir}:/data public.ecr.aws/aws-genomics/linter-rules-for-nextflow:v0.1