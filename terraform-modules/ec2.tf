locals {
  user_data = <<-EOT
  #!/bin/bash
  sudo yum update -y
  sudo swapoff -a
  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
  overlay
  br_netfilter
  EOF
  sudo modprobe overlay
  sudo modprobe br_netfilter
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
  net.bridge.bridge-nf-call-iptables  = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  net.ipv4.ip_forward                 = 1
  EOF
  sudo sysctl --system
  sudo yum install -y containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl restart containerd
  cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
  enabled=1
  gpgcheck=1
  gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
  exclude=kubelet kubeadm kubectl
  EOF
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  sudo systemctl enable --now kubelet
  sudo kubeadm init --control-plane-endpoint ${aws_eip.example.public_ip}:6443 --pod-network-cidr=192.168.0.0/16
  sleep 10
  sudo -u ec2-user mkdir -p /home/ec2-user/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
  sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
  EOT
}
module "ec2_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.name}-ec2-sg"
  description = "EC2 security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      description = "Allow all trafic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow ssh"
      protocol    = "TCP"
      from_port   = 22
      to_port     = 22
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      description = "Allow all trafic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = "0.0.0.0/0"
    }
  ]

}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "hands-on-ec2"
  create_private_key = true
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  # for_each = toset(var.ec2_name)
  name = "${var.name}-ec2-instance"

  ami                    = "ami-026b57f3c383c2eec"
  instance_type          = "t3.medium"
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data              = local.user_data
}

resource "local_file" "ssh_key" {
  filename = "test.pem"
  content  = module.key_pair.private_key_pem
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = module.ec2_instance.id
  allocation_id = aws_eip.example.id
}

resource "aws_eip" "example" {
  vpc = true
}
