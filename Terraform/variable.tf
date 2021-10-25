variable "cluster-name" {
 default = "bryan-tf-eks"
 type = string
}

variable "AWS_REGION" {
 default = "us-east-2" 
}

variable "profile" {
    description = "Which profile to use for IAM"
}