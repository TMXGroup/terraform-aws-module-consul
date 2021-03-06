terraform {
  required_version = ">= 0.11.5"
}

module "consul_auto_join_instance_role" {
  source = "github.com/hashicorp-modules/consul-auto-join-instance-role-aws"

  create = "${var.create ? 1 : 0}"
  name   = "${var.name}"
}

data "template_file" "consul_init" {
  count    = "${var.create ? 1 : 0}"
  template = "${file("${path.module}/templates/init-systemd.sh.tpl")}"

  vars = {
    name      = "${var.name}"
    user_data = "${var.user_data != "" ? var.user_data : "echo 'No custom user_data'"}"
  }
}

module "consul_server_sg" {
  source = "github.com/TMXGroup/terraform-aws-module-consul-server-ports"

  create            = "${var.create ? 1 : 0}"
  name              = "${var.name}-consul-server"
  vpc_id            = "${var.vpc_id}"
  cidr_blocks       = ["${var.public ? "0.0.0.0/0" : var.vpc_cidr}"] # If there's a public IP, open Consul ports for public access - DO NOT DO THIS IN PROD
  vault_sg_group   = "${var.vault_sg_id}" 
  tags              = "${var.tags}"
}

module "consul_lb_aws" {
  source = "github.com/TMXGroup/terraform-aws-module-consul-lb-aws"

  create             = "${var.create}"
  name               = "${var.name}"
  vpc_id             = "${var.vpc_id}"
  cidr_blocks        = ["${var.public ? "0.0.0.0/0" : var.vpc_cidr}"] # If there's a public IP, open port 22 for public access - DO NOT DO THIS IN PROD
  subnet_ids         = ["${var.subnet_ids}"]
  is_internal_lb     = "${!var.public}"
  use_lb_cert        = "${var.use_lb_cert}" 
  lb_cert            = "${var.lb_cert}"
  lb_private_key     = "${var.lb_private_key}"
  lb_cert_chain      = "${var.lb_cert_chain}"
  lb_ssl_policy      = "${var.lb_ssl_policy}"
  lb_bucket          = "${var.lb_bucket}"
  lb_bucket_override = "${var.lb_bucket_override}"
  lb_bucket_prefix   = "${var.lb_bucket_prefix}"
  lb_logs_enabled    = "${var.lb_logs_enabled}"
  s3_logging_target  = "${var.s3_logging_target}"
  tags               = "${var.tags}"
}

resource "aws_security_group_rule" "ssh" {
  count = "${var.create ? 1 : 0}"

  security_group_id = "${module.consul_server_sg.consul_server_sg_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["${var.bastion_ip}"] 
  description       = "Bastion host"
}

resource "aws_launch_configuration" "consul" {
  count = "${var.create ? 1 : 0}"

  name_prefix                 = "${format("%s-consul-", var.name)}"
  associate_public_ip_address = "${var.public}"
  ebs_optimized               = false
  instance_type               = "${var.instance_type}"
  image_id                    = "${var.image_id}"
  iam_instance_profile        = "${var.instance_profile != "" ? var.instance_profile : module.consul_auto_join_instance_role.instance_profile_id}"
  user_data                   = "${data.template_file.consul_init.rendered}"
  key_name                    = "${var.ssh_key_name}"

  security_groups = [
    "${module.consul_server_sg.consul_server_sg_id}",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "consul" {
  count = "${var.create ? 1 : 0}"

  name_prefix          = "${aws_launch_configuration.consul.name}"
  launch_configuration = "${aws_launch_configuration.consul.id}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  max_size             = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  min_size             = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  desired_capacity     = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  default_cooldown     = 30
  force_delete         = true

  target_group_arns = ["${compact(concat(
    list(
      module.consul_lb_aws.consul_tg_http_8500_arn,
      module.consul_lb_aws.consul_tg_https_8080_arn,
    ),
    var.target_groups
  ))}"]

  tags = ["${concat(
    list(
      map("key", "Name", "value", format("%s-consul-node", var.name), "propagate_at_launch", true),
      map("key", "Consul-Auto-Join", "value", var.name, "propagate_at_launch", true)
    ),
    var.tags_list
  )}"]

  lifecycle {
    create_before_destroy = true
  }
}
