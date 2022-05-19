# Playground AKS Maintenance

Playground for AKS and maintenance tasks

## Discussion topics

- Kubernetes core concepts
  - [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
  - [PodDisruptionBudget ](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
  - [Think about how your application reacts to disruptions](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#think-about-how-your-application-reacts-to-disruptions)
  - [Deprecated API Migration Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
    - You can use `Cluster Insights` in AKS to see potential problems in this area:
      1. Open AKS in Azure Portal
      2. Select `Diagnose and solve problems`
      3. At very bottom of the page there is link to `Cluster Insights`
      4. Click `Kubernetes API Deprecations` to see if AKS has found any usage of deprecated APIs
         - Similarly it has other "deprecated" views to check.
- AKS
  - Cluster upgrades
    - [AKS Kubernetes Release Calendar](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar)
    - [Upgrade an Azure Kubernetes Service (AKS) cluster](https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster)
    - [Set auto-upgrade channel](https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster#set-auto-upgrade-channel)
  - Other upgrades and updates
    - [Node image upgrade](https://docs.microsoft.com/en-us/azure/aks/node-image-upgrade#upgrade-node-images-with-node-surge)
    - [Node OS updates](https://docs.microsoft.com/en-us/azure/aks/node-updates-kured)
- Persistent storage
  - [Impact of Availability Zones](https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster#special-considerations-for-node-pools-that-span-multiple-availability-zones)
  - [Azure Disk & workload updates](https://github.com/JanneMattila/playground-aks-storage/blob/main/updates.md#workload-deployment-updates)
- Re-create or upgrade cluster
  - Important: Static vs. dynamic persistent storages and their lifecycle management if using [MC_*](https://docs.microsoft.com/en-us/azure/aks/faq#why-are-two-resource-groups-created-with-aks) resource group!
    - > AKS automatically deletes the node resource group whenever the cluster is deleted, so it should only be used for resources that share the cluster's lifecycle.
