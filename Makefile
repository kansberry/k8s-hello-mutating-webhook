WEBHOOK_SERVICE?=mutating-webhook-service
NAMESPACE?=default
CONTAINER_REPO?=kansberrycincom/mutating-webhook
CONTAINER_VERSION?=0.0.1
CONTAINER_IMAGE=$(CONTAINER_REPO):$(CONTAINER_VERSION)

.PHONY: docker-build
docker-build:
	docker build -t $(CONTAINER_IMAGE) webhook

.PHONY: docker-push
docker-push:
	docker push $(CONTAINER_IMAGE) 

.PHONY: k8s-deploy
k8s-deploy: k8s-deploy-other k8s-deploy-csr k8s-deploy-deployment

.PHONY: k8s-deploy-other
k8s-deploy-other:
	kustomize build k8s/other | microk8s kubectl apply -f -
	kustomize build k8s/csr | microk8s kubectl apply -f -
	@echo Waiting for cert creation ...
	@sleep 15
	microk8s kubectl certificate approve $(WEBHOOK_SERVICE).$(NAMESPACE)

.PHONY: k8s-deploy-csr
k8s-deploy-csr:
	kustomize build k8s/csr | microk8s kubectl apply -f -
	@echo Waiting for cert creation ...
	@sleep 15
	microk8s kubectl certificate approve $(WEBHOOK_SERVICE).$(NAMESPACE)

.PHONY: k8s-deploy-deployment
k8s-deploy-deployment:
	(cd k8s/deployment && \
	kustomize edit set image CONTAINER_IMAGE=$(CONTAINER_IMAGE))
	kustomize build k8s/deployment | microk8s kubectl apply -f -

.PHONY: k8s-delete-all
k8s-delete-all:
	kustomize build k8s/other | microk8s kubectl delete --ignore-not-found=true -f  - 
	kustomize build k8s/csr | microk8s kubectl delete --ignore-not-found=true -f  - 
	kustomize build k8s/deployment | microk8s kubectl delete --ignore-not-found=true -f  - 
	microk8s kubectl delete --ignore-not-found=true csr $(WEBHOOK_SERVICE).$(NAMESPACE)
	microk8s kubectl delete --ignore-not-found=true secret hello-tls-secret

.PHONY: test
test:
	cd webhook && go test ./...
