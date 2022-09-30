locals {
  user_data = <<-EOT
  #!/bin/bash
  sudo apt-get update && apt install docker.io -y
  sudo apt-get update && apt-get install -y apt-transport-https curl 
  sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb https://apt.kubernetes.io/ kubernetes-xenial main
  EOF
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  sudo swapoff -a
  sudo kubeadm init --control-plane-endpoint ${aws_eip.example.public_ip}:6443 --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem
  sudo -u ubuntu mkdir -p /home/ubuntu/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
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

  ami                    = "ami-08c40ec9ead489470"
  instance_type          = "t2.medium"
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
