# # Istio Base
# resource "helm_release" "istio_base" {
#   name             = "istio-base"
#   repository       = "https://istio-release.storage.googleapis.com/charts"
#   chart            = "base"
#   version          = "1.24.2"
#   namespace        = "istio-system"
#   create_namespace = true

#   depends_on = [aws_eks_cluster.ecommerce-prod-cluster]
# }

# # Istiod (Discovery)
# resource "helm_release" "istio_discovery" {
#   name       = "istiod"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "istiod"
#   version    = "1.24.2"
#   namespace  = "istio-system"

#   depends_on = [helm_release.istio_base]
# }

# # Istio Ingress Gateway
# resource "helm_release" "istio_ingress" {
#   name       = "istio-ingress"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "gateway"
#   version    = "1.24.2"
#   namespace  = "istio-system"

#   set {
#     name  = "service.type"
#     value = "LoadBalancer"
#   }

#   depends_on = [helm_release.istio_discovery]
# }

# # Kiali
# resource "helm_release" "kiali" {
#   name       = "kiali"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "kiali-server"
#   version    = "1.24.2"
#   namespace  = "istio-system"

#   set {
#     name  = "service.type"
#     value = "LoadBalancer"
#   }

#   depends_on = [helm_release.istio_discovery]
# }
