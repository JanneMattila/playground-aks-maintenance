#!/bin/bash

# All the variables for the deployment
subscriptionName="AzureDev"
aadAdminGroupContains="janne''s"

aksName="myaksmaintenance"
acrName="myacrmaintenance0000010"
workspaceName="mymaintenanceworkspace"
vnetName="mymaintenance-vnet"
subnetAks="aks-subnet"
identityName="myaksmaintenance"
resourceGroupName="rg-myaksmaintenance"
location="northeurope"

# Login and set correct context
az login -o table
az account set --subscription $subscriptionName -o table

# Prepare extensions and providers
az extension add --upgrade --yes --name aks-preview

# Enable features
az feature register --namespace "Microsoft.ContainerService" --name "EnablePodIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-ScaleDownModePreview"
az feature register --namespace "Microsoft.ContainerService" --name "PodSubnetPreview"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePodIdentityPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-ScaleDownModePreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/PodSubnetPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

# Remove extension in case conflicting previews
# az extension remove --name aks-preview
subscriptionID=$(az account show -o tsv --query id)
resourcegroupid=$(az group create -l $location -n $resourceGroupName -o table --query id -o tsv)
echo $resourcegroupid

acrid=$(az acr create -l $location -g $resourceGroupName -n $acrName --sku Basic --query id -o tsv)
echo $acrid

aadAdmingGroup=$(az ad group list --display-name $aadAdminGroupContains --query [].id -o tsv)
echo $aadAdmingGroup

workspaceid=$(az monitor log-analytics workspace create -g $resourceGroupName -n $workspaceName --query id -o tsv)
echo $workspaceid

vnetid=$(az network vnet create -g $resourceGroupName --name $vnetName \
  --address-prefix 10.0.0.0/8 \
  --query newVNet.id -o tsv)
echo $vnetid

subnetaksid=$(az network vnet subnet create -g $resourceGroupName --vnet-name $vnetName \
  --name $subnetAks --address-prefixes 10.1.0.0/20 \
  --query id -o tsv)
echo $subnetaksid

identityjson=$(az identity create --name $identityName --resource-group $resourceGroupName -o json)
identityid=$(echo $identityjson | jq -r .id)
identityobjectid=$(echo $identityjson | jq -r .principalId)
echo $identityid
echo $identityobjectid

az aks get-versions -l $location -o table

# Note about private clusters:
# https://docs.microsoft.com/en-us/azure/aks/private-clusters

# For private cluster add these:
#  --enable-private-cluster
#  --private-dns-zone None

az aks create -g $resourceGroupName -n $aksName \
 --max-pods 50 --network-plugin azure \
 --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 3 \
 --node-osdisk-type "Ephemeral" \
 --node-vm-size "Standard_D8ds_v4" \
 --kubernetes-version 1.19.11 \
 --enable-addons monitoring \
 --enable-aad \
 --enable-managed-identity \
 --disable-local-accounts \
 --aad-admin-group-object-ids $aadAdmingGroup \
 --workspace-resource-id $workspaceid \
 --attach-acr $acrid \
 --load-balancer-sku standard \
 --vnet-subnet-id $subnetaksid \
 --assign-identity $identityid \
 -o table

# Create secondary node pool
nodepool2="nodepool2"
az aks nodepool add -g $resourceGroupName --cluster-name $aksName \
  --name $nodepool2 \
  --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 3 \
  --node-osdisk-type "Ephemeral" \
  --node-vm-size "Standard_D8ds_v4" \
  --node-taints "usage=limitedaccess:NoSchedule" \
  --labels usage=limitedaccess \
  --max-pods 150

# az aks nodepool delete -g $resourceGroupName --cluster-name $aksName --name $nodepool2

sudo az aks install-cli

az aks get-credentials -n $aksName -g $resourceGroupName --overwrite-existing

kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl get nodes --show-labels=true
kubectl get nodes -L agentpool,usage
kubectl get nodes -o=custom-columns="NAME:.metadata.name,ADDRESSES:.status.addresses[?(@.type=='InternalIP')].address,PODCIDRS:.spec.podCIDRs[*]"

############################################
#  _   _      _                      _
# | \ | | ___| |___      _____  _ __| | __
# |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ /
# | |\  |  __/ |_ \ V  V / (_) | |  |   <
# |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\
# Tester web app demo
############################################

# Deploy all items from demos namespace
kubectl apply -f demos/namespace.yaml
kubectl apply -f demos/deployment.yaml
kubectl apply -f demos/service.yaml

kubectl get deployment -n demos
kubectl describe deployment -n demos

pod=$(kubectl get pod -n demos -o name | head -n 1)
echo $pod

kubectl describe $pod -n demos

kubectl get service -n demos

svc_ip=$(kubectl get service -n demos -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
echo $svc_ip

curl $svc_ip/api/healthcheck
# -> <html><body>Hello there!</body></html>

# Test deployments
kubectl apply -f demos/deployment.yaml

kubectl rollout history deployment/webapp -n demos
kubectl rollout status deployment/webapp -n demos -w
kubectl annotate deployment/webapp -n demos kubernetes.io/change-cause="Deployment release #123"

kubectl get deployment -n demos -o wide -w

kubectl rollout undo deployment/webapp -n demos
kubectl rollout undo deployment/webapp -n demos --to-revision=2

# Get number of pods per node
kubectl get pod -n demos --no-headers=true -o custom-columns=NODE:'{.spec.nodeName}' | sort | uniq -c | sort -n

# Test scaling
kubectl scale deployment/webapp -n demos --replicas=3

# Test image updates
kubectl set image deployment/webapp -n demos webapp=jannemattila/webapp:1.0.10

# Updates
kubectl get nodes -o wide
# If not using 
# az aks nodepool scale -g $resourceGroupName --cluster-name $aksName --name nodepool1 --node-count 1
az aks get-versions -l $location -o table
az aks get-upgrades -g $resourceGroupName -n $aksName -o table
az aks nodepool get-upgrades --nodepool-name nodepool1 -g $resourceGroupName --cluster-name $aksName -o table

# Update max surge for an existing node pool
# Note: For production node pools, we recommend a max_surge setting of 33%
az aks nodepool update -n nodepool1 -g $resourceGroupName --cluster-name $aksName --max-surge 1

time az aks upgrade -g $resourceGroupName -n $aksName --kubernetes-version 1.21.2 --yes

time az aks upgrade -g $resourceGroupName -n $aksName --kubernetes-version 1.20.9 --control-plane-only --yes
time az aks nodepool upgrade --name nodepool1 -g $resourceGroupName --cluster-name $aksName --kubernetes-version 1.20.9

time az aks upgrade -g $resourceGroupName -n $aksName --kubernetes-version 1.19.13 --node-image-only --yes
kubectl get events

# Wipe out the resources
az group delete --name $resourceGroupName -y
