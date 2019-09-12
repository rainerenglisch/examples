echo "set kubectl context to kubeflow"
kubectl config set-context $(kubectl config current-context) --namespace=kubeflow
echo "install kustomize"
opsys=linux  # or darwin, or windows
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/tags/v2.0.3 |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -O -L
mv kustomize_*_${opsys}_amd64 kustomize
chmod u+x kustomize
export PATH=$PATH:$(pwd)

echo "rainers_example.sh TRAIN_NAME DOCKER_URL PVC_NAME"
DOCKER_URL=${2:-m1st3rb3an/kf_mnist_example1:dev}
TRAIN_NAME=${1:-'mnist-train-local-'$(date +%s)}
PVC_NAME=${3:-"workspace-rainer-kubeflow-example"}
echo "Using following parameter values"
echo "DOCKER_URL: "  $DOCKER_URL
echo "TRAIN_NAME: "  $TRAIN_NAME
echo "PVC_NAME: "  $PVC_NAME

echo "start customizing yamls"
#reseting training/local
git checkout training/local/*

cd training/local
kustomize edit add configmap mnist-map-training --from-literal=name=$TRAIN_NAME
kustomize edit set image training-image=$DOCKER_URL
../base/definition.sh --numPs 1 --numWorkers 2
kustomize edit add configmap mnist-map-training --from-literal=trainSteps=200
kustomize edit add configmap mnist-map-training --from-literal=batchSize=100
kustomize edit add configmap mnist-map-training --from-literal=learningRate=0.01
kustomize edit add configmap mnist-map-training --from-literal=pvcName=${PVC_NAME}
kustomize edit add configmap mnist-map-training --from-literal=pvcMountPath=/mnt
kustomize edit add configmap mnist-map-training --from-literal=modelDir=/mnt/${TRAIN_NAME}
kustomize edit add configmap mnist-map-training --from-literal=exportDir=/mnt/${TRAIN_NAME}/export

echo "Submitting training job to kubernetes cluster"
kustomize build . |kubectl apply -f -

echo "Querying tfjobs"
kubectl get tfjobs -o yaml $TRAIN_NAME

sleep 10s
echo "Tailing los"
kubectl logs --follow ${TRAIN_NAME}-chief-0
