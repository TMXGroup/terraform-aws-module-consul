module "images-aws" {
  source = "git@github.com:hashicorp-modules/images-aws.git//terraform?ref=f-image-filters"

  OS = "${var.OS}"
  OS-Version = "${var.OS-Version}"
  Consul-Version = "${var.Consul-Version}"

}

#resource "aws_cloudwatch_log_group" "consul_server" {
#	name = "${var.log_group_name}"
#}

resource "aws_iam_role" "consul_server" {
	name = "ConsulServer"
	assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "consul_server" {
	name = "SelfAssembly"
	role = "${aws_iam_role.consul_server.id}"
	policy = "${data.aws_iam_policy_document.consul_server.json}"
}

resource "aws_iam_instance_profile" "consul_server" {
	name = "ConsulServer"
	roles = ["${aws_iam_role.consul_server.name}"]
}

data "template_file" "init" {
  template = "${file("${path.module}/init-cluster.tpl")}"

  vars = {
        region = "${var.region}"
        cluster_name = "${var.cluster_name}"
  }
}

resource "aws_launch_configuration" "consul_server" {
	image_id = "${module.images-aws.consul_image}"
	instance_type = "${var.instance_type}"
	user_data = "${data.template_file.init.rendered}"
  key_name  = "${var.sshkey}"
	security_groups = [
		"${aws_security_group.consul_server.id}",
		"${aws_security_group.consul_client.id}"
	]
	associate_public_ip_address = false
	ebs_optimized = false
	iam_instance_profile = "${aws_iam_instance_profile.consul_server.id}"

	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "consul_server" {
	launch_configuration = "${aws_launch_configuration.consul_server.id}"
	vpc_zone_identifier = ["${var.subnets}"]

	name = "${var.cluster_name} Consul Servers"

	max_size = "${var.cluster_size}"
	min_size = "${var.cluster_size}"
	desired_capacity = "${var.cluster_size}"
	default_cooldown = 30
	force_delete = true

	tag {
		key = "Name"
		value = "${format("%s Consul Server", var.cluster_name)}"
		propagate_at_launch = true
	}

  tag {
    key = "Cluster-Name"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }
	
#	tag {
#		key = "tfe:log_group"
#		value = "${var.log_group_name}"
#		propagate_at_launch = true
#	}
#
#	tag {
#		key = "tfe:consul:serf_key"
#		value = "${var.consul_serf_key}"
#		propagate_at_launch = true
#	}
#	
#	tag {
#		key = "tfe:consul:circonus_token"
#		value = "${var.consul_circonus_token}"
#		propagate_at_launch = true
#	}
#	
#	tag {
#		key = "tfe:consul:tls_kms_bucket"
#		value = "${var.tls_key_bucket_name}"
#		propagate_at_launch = true
#	}
#	
#	tag {
#		key = "tfe:consul:snapshot_bucket"
#		value = "${var.backup_bucket_name}"
#		propagate_at_launch = true
#	}
#
#	tag {
#		key = "tfe:consul:dns_name"
#		value = "${var.dns_name}"
#		propagate_at_launch = true
#	}
#	
#	tag {
#		key = "tfe:consul:tld"
#		value = "${var.consul_tld}"
#		propagate_at_launch = true
#	}
#	
#	tag {
#		key = "tfe:consul:hosted_zone_id"
#		value = "${var.vpc_zone_id}"
#		propagate_at_launch = true
#	}
}
