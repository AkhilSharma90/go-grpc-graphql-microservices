# resource "helm_release" "prometheus_helm" {
#   name             = "prometheus"
#   repository       = "https://prometheus-community.github.io/helm-charts"
#   chart            = "kube-prometheus-stack"
#   version          = "62.3.1"
#   namespace        = "prometheus"
#   create_namespace = true
#   timeout          = 2000

#   values = [file("./prometheus-values.yaml")]

#   depends_on = [helm_release.argocd]
# }
