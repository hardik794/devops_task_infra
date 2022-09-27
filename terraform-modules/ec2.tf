locals {
  user_data = <<-EOT
  #!/bin/bash
  touch first.txt
  sudo su
  apt-get update && apt install docker.io -y
  touch second.txt
  apt-get update && apt-get install -y apt-transport-https curl 
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  touch thrid.txt
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb https://apt.kubernetes.io/ kubernetes-xenial main
  EOF
  touch forth.txt
  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  swapoff -a
  touch fifth.txt
  kubeadm init --control-plane-endpoint ${aws_eip.example.public_ip}:6443 --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem
  exit
  touch sixth.txt
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
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

  ami                    = "ami-08c40ec9ead489470"
  instance_type          = "t2.micro"
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data              = <<EOT
  #!/bin/bash -xe
  touch first.txt
  sudo su
  apt-get update && apt install docker.io -y
  touch second.txt
  apt-get update && apt-get install -y apt-transport-https curl 
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  touch thrid.txt
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb https://apt.kubernetes.io/ kubernetes-xenial main
  EOF
  touch forth.txt
  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  swapoff -a
  touch fifth.txt
  kubeadm init --control-plane-endpoint ${aws_eip.example.public_ip}:6443 --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem
  exit
  touch sixth.txt
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  EOT
  # user_data_replace_on_change = true
}

resource "local_file" "ssh_key" {
  filename = "test.pem"
  content  = module.key_pair.private_key_pem
}

# resource "aws_eip" "lb" {
#   instance = module.ec2_instance.id
#   vpc      = true
# }

resource "aws_eip_association" "eip_assoc" {
  instance_id   = module.ec2_instance.id
  allocation_id = aws_eip.example.id
}

resource "aws_eip" "example" {
  vpc = true
}
