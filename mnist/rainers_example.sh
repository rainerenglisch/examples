# set context to kubeflow
kubectl config set-context $(kubectl config current-context) --namespace=kubeflow
# install kustomize
opsys=linux  # or darwin, or windows
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/tags/v2.0.3 |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -O -L
mv kustomize_*_${opsys}_amd64 kustomize
chmod u+x kustomize
export PATH=$PATH:$(pwd)
#set docker url
export DOCKER_URL=m1st3rb3an/kf_mnist_example1:dev
export TRAIN_NAME=mnist-train-local
export PVC_NAME=workspace-rainer-kubeflow-example
# start customizing yamls
cd training/local
kustomize edit add configmap mnist-map-training --from-literal=name=$TRAIN_NAME
kustomize edit set image training-image=$DOCKER_URL
../base/definition.sh --numPs 1 --numWorkers 2
kustomize edit add configmap mnist-map-training --from-literal=trainSteps=200
kustomize edit add configmap mnist-map-training --from-literal=batchSize=100
kustomize edit add configmap mnist-map-training --from-literal=learningRate=0.01
kustomize edit add configmap mnist-map-training --from-literal=pvcName=${PVC_NAME}
kustomize edit add configmap mnist-map-training --from-literal=pvcMountPath=/mnt
kustomize edit add configmap mnist-map-training --from-literal=modelDir=/mnt
kustomize edit add configmap mnist-map-training --from-literal=exportDir=/mnt/export

kustomize build . |kubectl apply -f -

kubectl get tfjobs -o yaml $TRAIN_NAME

kubectl logs --follow $TRAIN_NAME-chief-0
