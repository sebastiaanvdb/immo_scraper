#!/usr/bin/env bash
.PHONY: clean data lint requirements sync_data_to_s3 sync_data_from_s3

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR       := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUCKET             = immo_scraper
PROFILE            = default
PROJECT_NAME       = immo_scraper
PYTHON_INTERPRETER = python3
GCE_NAME           = /

#################################################################################
# COMMANDS                                                                      #
#################################################################################

## enter docker
enter_docker:
	docker exec -it $(PROJECT_NAME) bash;

## run gpu
run_gpu: build_gpu
	docker run -it --name  $(PROJECT_NAME) \
	--runtime nvidia \
	-p 8888:8888 \
	-p 6006:6006 \
	-v `pwd`/:/app \
	$(PROJECT_NAME);

## run no gpu
run_no_gpu: build_no_gpu
	docker run -it --name  $(PROJECT_NAME) \
	-p 8888:8888 \
	-p 6006:6006 \
	-v `pwd`/:/app \
	$(PROJECT_NAME);


## (ARG=FOLDER) Upload Data to gs
sync_data_to_gs:
	gsutil -m rsync -d -r $(FOLDER) gs://$(BUCKET)/$(FOLDER)


## (ARG=FOLDER) Rsync src, scripts from vm
rsync_FOLDER_from_vm:
	rsync -ave ssh $(GCE_NAME):~/$(PROJECT_NAME)/$(FOLDER)/ ./$(FOLDER)/


## init directory after clone
init:
	mkdir data || echo dir already created
	mkdir logs || echo dir already created
	touch logs/app.log || echo file already created
	cd data && mkdir raw || echo dir already created;
	cd data && mkdir interim || echo dir already created;
	cd data && mkdir processed || echo dir already created;
	gsutil -m rsync  -d -r  gs://$(BUCKET)/data/raw/ data/raw/;
	cd
	make raw_data_tree
## run all tests
test:
	pytest

## run the data preprocessing
preprocess:
	#remove data
	rm -rf data/interim
	rm -rf data/processed
	cd data && mkdir interim || echo dir already created;
	cd data && mkdir processed || echo dir already created;
	python src/preprocess.py

## train the cable classifier
train:
	cd
	python src/train.py


## run the model evaluation 
evaluate:
	cd
	python src/evaluation.py

## build complete workflow
build: clean preprocess train evaluate

## Setup SSH tunnels
setup_tunnels:
	ssh -Nf -L 8888:localhost:8888 $(GCE_NAME)
	ssh -Nf -L 6006:localhost:6006 $(GCE_NAME)
	while True; do \
		rsync -ave ssh README.md  .dockerignore  ./Pipfile ./Pipfile.lock  ./src  ./docker  ./configs ./Makefile ./setup.py $(GCE_NAME):~/$(PROJECT_NAME)/; \
		sleep 1; \
	done

## dump a tree structure of all raw data
raw_data_tree:
	tree -d ./data/raw > raw_data_tree.txt

## setup ssh keys
setup_ssh_keys:
	gcloud compute config-ssh;
	nano ~/.ssh/config

# run rsync to synchronize local project to gcloud
rsync_src_to_vm:
	rsync -ave ssh ./src  ./docker .dockerignore ./Makefile ./setup.py $(GCE_NAME):~/$(PROJECT_NAME)/;

# sync raw data from bucket to project 
sync_data_from_gs:
	gsutil -m rsync  -d -r  gs://$(BUCKET)/data/raw/ data/raw/;

## clean temporary files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete
	find . -name '.DS_Store' -type f -delete

## activate pipenv shell
enter_pipenv:
	pipenv shell

## de-activate pipenv shell
exit_pipenv:
	exit

# build docker image without GPU
build_no_gpu:
	docker stop $(PROJECT_NAME);docker rm  $(PROJECT_NAME);docker build -f docker/no_gpu/Dockerfile -t $(PROJECT_NAME) .

# build docker image with GPU
build_gpu:
	docker stop $(PROJECT_NAME);docker rm  $(PROJECT_NAME);docker build -f docker/gpu/Dockerfile -t $(PROJECT_NAME) .




#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
