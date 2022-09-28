locals {
  user_data = <<EOT
  #!/bin/bash
  touch $HOME/first.txt
  sudo apt-get update && apt install docker.io -y
  touch $HOME/second.txt
  sudo apt-get update && apt-get install -y apt-transport-https curl 
  sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  touch $HOME/thrid.txt
  sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb https://apt.kubernetes.io/ kubernetes-xenial main
  EOF
  touch $HOME/forth.txt
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  sudo swapoff -a
  touch $HOME/fifth.txt
  sudo kubeadm init --control-plane-endpoint ${aws_eip.example.public_ip}:6443 --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem
  touch $HOME/sixth.txt
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

  ami                    = "ami-0efda064d1b5e46a5"
  instance_type          = "t3.micro"
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
