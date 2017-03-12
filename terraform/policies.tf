data "aws_iam_policy_document" "assume_role" {
	statement {
		effect = "Allow"
		actions = [
			"sts:AssumeRole",
		]
		principals {
			type = "Service"
			identifiers = ["ec2.amazonaws.com"]
		}
	}
}

data "aws_iam_policy_document" "consul_server" {
	statement {
		sid = "AllowSelfAssembly"
		effect = "Allow"
		resources = ["*"]
		actions = [
			"autoscaling:DescribeAutoScalingGroups",
			"autoscaling:DescribeAutoScalingInstances",
			"ec2:DescribeAvailabilityZones",
			"ec2:DescribeInstanceAttribute",
			"ec2:DescribeInstanceStatus",
			"ec2:DescribeInstances",
			"ec2:DescribeTags",
		]
	}
	statement {
		sid = "AllowRoute53Registration"
		effect = "Allow"
		resources = ["*"]
		actions = [
			"route53:GetHostedZone",
			"route53:ChangeResourceRecordSets",
		]
	}
	statement {
		sid = "AllowConsulBackups"
		effect = "Allow"
		resources = [
			"${var.backup_bucket_arn}",
			"${var.backup_bucket_arn}/*",
		]
		#TODO(jen20): Narrow the scope of this when it is documented
		actions = [
			"s3:*"
		]
	}
	statement {
		sid = "AllowConsulTLSKeysAccess"
		effect = "Allow"
		resources = [
			"${var.tls_key_bucket_arn}/consul/*",
		]
		actions = [
			"s3:GetObject"
		]
	}
	statement {
		sid = "AllowTLSKeyDecrypt"
		effect = "Allow"
		resources = [
			"${var.tls_kms_arn}"
		]
		actions = [
			"kms:Decrypt"
		]
	}
	statement {
		effect = "Allow"
		actions = [
			"logs:CreateLogStream",
			"logs:PutLogEvents",
			"logs:DescribeLogStreams"
		]
		resources = [
			"arn:aws:logs:*:*:log-group:${var.log_group_name}",
			"arn:aws:logs:*:*:log-group:${var.log_group_name}:log-stream:*"
		]
	}
}
