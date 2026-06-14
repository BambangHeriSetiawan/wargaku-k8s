# ── IAM — control plane ───────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name  = "estathub-${var.environment}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

# ── IAM — node group ──────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name  = "estathub-${var.environment}-eks-nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes[0].name
}

# ── Networking — use default VPC to avoid managing subnets ────────────────────

data "aws_vpc" "default" {
  count   = var.cloud_provider == "aws" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.cloud_provider == "aws" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# ── EKS cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  name     = "estathub-${var.environment}"
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.k8s_version != "" ? var.k8s_version : null

  vpc_config {
    subnet_ids = data.aws_subnets.default[0].ids
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_node_group" "main" {
  count           = var.cloud_provider == "aws" ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = data.aws_subnets.default[0].ids
  instance_types  = [var.aws_node_instance_type]

  scaling_config {
    desired_size = var.node_count
    min_size     = 1
    max_size     = var.node_count + 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_ecr_read,
  ]
}

# ── kubeconfig — uses the AWS CLI exec plugin for token refresh ───────────────

resource "local_sensitive_file" "kubeconfig_aws" {
  count           = var.cloud_provider == "aws" ? 1 : 0
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"

  content = <<-YAML
    apiVersion: v1
    kind: Config
    clusters:
      - name: ${aws_eks_cluster.main[0].name}
        cluster:
          server: ${aws_eks_cluster.main[0].endpoint}
          certificate-authority-data: ${aws_eks_cluster.main[0].certificate_authority[0].data}
    users:
      - name: aws
        user:
          exec:
            apiVersion: client.authentication.k8s.io/v1beta1
            command: aws
            args:
              - eks
              - get-token
              - --cluster-name
              - ${aws_eks_cluster.main[0].name}
              - --region
              - ${var.aws_region}
    contexts:
      - name: ${aws_eks_cluster.main[0].name}
        context:
          cluster: ${aws_eks_cluster.main[0].name}
          user: aws
    current-context: ${aws_eks_cluster.main[0].name}
  YAML

  depends_on = [aws_eks_node_group.main]
}
