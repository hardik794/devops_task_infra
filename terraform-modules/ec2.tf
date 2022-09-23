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
  source   = "terraform-aws-modules/ec2-instance/aws"
  version  = "~> 3.0"
  for_each = toset(var.ec2_name)
  name     = "${each.key}-ec2-instance"

  ami           = "ami-08c40ec9ead489470"
  instance_type = "t2.micro"
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
}

resource "local_file" "ssh_key" {
  filename = "test.pem"
  content = module.key_pair.private_key_pem
}
 