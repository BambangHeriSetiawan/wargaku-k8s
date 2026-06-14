# ── Namespace ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "estathub" {
  metadata {
    name = "estathub"
  }

  depends_on = [civo_kubernetes_cluster.main]
}

# ── nginx-ingress ─────────────────────────────────────────────────────────────
# Provisions a Civo LoadBalancer automatically (~free on Civo, 1 included)

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  # Keep resource requests low for a single-node cluster
  set {
    name  = "controller.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "90Mi"
  }

  depends_on = [civo_kubernetes_cluster.main]
}

# ── cert-manager ──────────────────────────────────────────────────────────────
# Automates free TLS certificates via Let's Encrypt

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.15.0"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "resources.requests.memory"
    value = "32Mi"
  }

  depends_on = [helm_release.ingress_nginx]
}

# ── ClusterIssuer (Let's Encrypt) ─────────────────────────────────────────────
# Applied after cert-manager CRDs are installed

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.alert_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "nginx"
            }
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}
