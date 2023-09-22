APP_PORT := 5000
LOCAL_PORT := 8080
DOCKER_TAG := latest
DOCKER_IMAGE := satellite

DEPLOY_HOST := demo_host
KEY_FILE := ~/.ssh/id_rsa
DVC_REMOTE_NAME := my_remote
CONTAINER_NAME := j.polushina_satellite

.PHONY: run_app
run_app:
	python3 -m uvicorn app:create_app --host='0.0.0.0' --port=$(APP_PORT)

.PHONY: install
install:
	pip install -r requirements.txt -f https://download.pytorch.org/whl/torch_stable.html

.PHONY: download_weights
download_weights:
	dvc pull weights/final_model.pt.dvc

.PHONY: run_unit_tests
run_unit_tests:
	PYTHONPATH=. pytest tests/unit/

.PHONY: run_integration_tests
run_integration_tests:
	PYTHONPATH=. pytest -s tests/integration/

.PHONY: run_all_tests
run_all_tests:
	make run_unit_tests
	make run_integration_tests

.PHONY: generate_coverage_report
generate_coverage_report:
	PYTHONPATH=. pytest --cov=src --cov-report html  tests/

.PHONY: lint
lint:
	flake8 src/


.PHONY: build
build:
	docker build -f Dockerfile . --force-rm=true -t $(DOCKER_IMAGE):$(DOCKER_TAG)


.PHONY: deploy
deploy:
	ansible-playbook -i deploy/ansible/inventory.ini  deploy/ansible/deploy.yml \
		-e host=$(DEPLOY_HOST) \
		-e docker_image=$(DOCKER_IMAGE) \
		-e docker_tag=$(DOCKER_TAG) \
		-e docker_registry_user=$(CI_REGISTRY_USER) \
		-e docker_registry_password=$(CI_REGISTRY_PASSWORD) \
		-e docker_registry=$(CI_REGISTRY) \


.PHONY: destroy
destroy:
	ansible-playbook -i deploy/ansible/inventory.ini deploy/ansible/destroy.yml \
		-e host=$(DEPLOY_HOST)

.PHONY: install_dvc
install_dvc:
	pip install 'pygit2==1.10.1' 
	pip install 'pathspec==0.9.0'
	pip install 'dvc==3.15.3'
	pip install 'dvc[ssh]'


.PHONY: init_dvc
init_dvc:
	dvc init --no-scm
	dvc remote add --default $(DVC_REMOTE_NAME) ssh://91.206.15.25/home/$(USERNAME)/dvc_files
	dvc remote modify $(DVC_REMOTE_NAME) user $(USERNAME)
	dvc config cache.type hardlink,symlink

.PHONY: install_c_libs
install_c_libs:
	apt-get update && apt-get install -y --no-install-recommends gcc ffmpeg libsm6 libxext6


.PHONY: docker_run
docker_run:
	docker run \

		-d \
		-p $(LOCAL_PORT):5000 \
		--name  $(CONTAINER_NAME) \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
