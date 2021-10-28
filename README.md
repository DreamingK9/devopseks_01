# DevOps Terraform and EKS

This project deploys a small cluster on AWS using terraform.
## Requirements
- AWS IAM User with Administrator Access permission and promgrammatic access.
- Terraform.
- AWS CLI.
- Kubctl.
- I'll be using VS code you can use your personal prefence of code editor or ide.
I'll be setting up this project in an Ubuntu OS so please be wary of changes the commands to your packet manager if using different OS.
I'll also be implementing the vs code in my OS to edit my code.

## Installation
### Terraform
https://learn.hashicorp.com/tutorials/terraform/install-cli
• Ensure that your system is up to date, and you have the gnupg, software-properties-common, and curl packages installed. You will use these packages to verify HashiCorp's GPG signature, and install HashiCorp's Debian package repository.

`
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
`

• Add the HashiCorp GPG key.
`
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
`

• Add the official HashiCorp Linux repository.
`
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
`

• Update to add the repository, and install the Terraform CLI.
`
sudo apt-get update && sudo apt-get install terraform
`

### AWS
• Prerequisetes
`sudo apt install unzip`

AWS setup
• Then download AWS
`
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"`
`unzip awscliv2.zip`
`sudo ./aws/install`

• Remember to remove the zip afterwards with 
`rm -r zip-file-name`

• Remember to update if doesn’t let you download package/install
`sudo apt-get update`

## Kubectl
• Normal Kubernetes Docs
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

• Specifically, we’re doing for the following EKS Docs
https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

• To install kubectl on Linux
1.	Download the Amazon EKS vended kubectl binary for your cluster's Kubernetes version from Amazon S3. To download the Arm version, change amd64 to arm64 before running the command.
-	Kubernetes 1.21:
`curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl`

• Apply execute permissions to the binary.
- `chmod +x ./kubectl`

• Copy the binary to a folder in your PATH. If you have already installed a version of kubectl, then we recommend creating a $HOME/bin/kubectl and ensuring that $HOME/bin comes first in your $PATH. 
- `mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin`

• (Optional) Add the $HOME/bin path to your shell initialization file so that it is configured when you open a shell.
• This step assumes you are using the Bash shell; if you are using another shell, change the command to use your specific shell initialization file. 
- `echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc`

• After you install kubectl , you can verify its version with the following command: 
-	`kubectl version --short --client`

## Procedure
• Create a project directory 
- `mkdir devopseks_01`
then create a sub folder for terraform files
- `mkdir Terraform`

•BEWARE
- Note for users planning to upload this project to github ensure to use the gitignore correctly to not push credentials or secrets to the public. please follow the recommendations [here](https://github.com/github/gitignore/blob/master/Terraform.gitignore)

### AWS Configurations

• After creating your user that has programmatic access to with permissions to services you will be deploying on AWS, you grab the public and private keys that you got after creating the user and insert the name of the user you created in the following. 
- `aws configure --profile DevOpsUser`
• You'll then be asked for your public key, private key, and region(example region is us-west-1).

### Terraform EKS
• We'll be using the resources and modules from [terraform registry for aws modules](https://registry.terraform.io/providers/hashicorp/aws/latest)

• We start with creating several files for our project applying the modules from terraform to them.
    - `vpc.tf`
    - `variables.tf`
    - `provider.tf`
    - `iam.tf`
    - `ekscluster.tf`

VPC
`vpc.tf`
```terraform
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
   Name = "${var.cluster-name}-vpc"
  }
}
```

• The VPC module list out the following code and you adjust to your needs. 
To get the `version` you can check the terraform registry via: 
- Search vpc
- Click modules
- Then select the vpc and you'll see it on the top right.

• `aws_availbility_zones` will depend on the region and that region must have 3 AZs 
• The tag cluster-name is references from the `variables.tf` file

Variables
`variable.tf`
```
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
```
• We changed from what the registry has to add our profile so we may give terraform secure access to deploy services without putting our credentials in the code

• In the `variable.tf` you include `profile` description this is a ref to our earlier input of `aws profiles`

Provider
`provider.tf`
```
provider "aws" {
  region = var.AWS_REGION
  profile = var.profile
}

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
}

provider "http" {
}
```

- For provider we modified the module to add the aws profile variable so terraform can deploy onto aws
- Ensure in your `provider.tf` of aws you issue the `profile = var.profile`
- `aws_region` will choose the `current`
- `aws_availbility_zones` will choose `available` zones


iam
`iam.tf`
```
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_nodes" {
  name = "eks-node-group-bryan"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

```
- We are creating a resource that is `aws_iam_role` named `eks_cluster`

- Means this role will be created for the `eks_cluster`
- The name of this role will be `eks-cluster` while the resource is called `eks_cluster`

- The `assume_role_policy` will assign a policy to the role we just created.

- You can go directly to the policy on the aws console where you can copy this exact json.

• Next we’re going to bind a few policies to this role 

- `aws_iam_role_policy_attachment` = any policy mention afterwards will be bonded to a specified role

- `AmazonEKSClusterPolicy` = this is a policy we’re specifying that we’ll have bonded

- `eks_cluster` is the role we created above.
These policies are needed so we can create the EKS cluster

• Next we create another role
- `eks_nodes` This role we’re making is specifically for the nodes 
- The difference is this role will assume an ec2 policy will the one before assumed and eks role

• Next we attach a few policy to the `eks_nodes`
- You’ll see we attach the EKS worker node policy

- This will help us attach the worker nodes to the cluster and create the communication between the worker nodes and the EKS Cluster

EKSCluster
`ekscluster.tf`
```
resource "aws_eks_cluster" "aws_eks" {
  name     = "eks_cluster_bryan"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = module.vpc.public_subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,  
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
  ]

  tags = {
    Name = "EKS_Cluster_Bryan"
  }
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = "node_bryan"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = module.vpc.public_subnets

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
```
- The resource `aws_eks_cluster` name of the resource will `aws_eks` 
- The name of the actual cluster will be `eks_cluster_levelup`
- Here we’re choosing the `role_arn` where we specify what role we will use, `eks_cluster` the role we created in the `iam.tf` 
`vpc_config`
- `Subnet_ids` has the `public_subnets` which is referenced to the `vpc.tf`

- Now onto `depends_on`
    - Here we attach the 2 policies `EKSClusterPolicy` and `EKSServicePolicy`
    - Those were the ones we mentioned in the `iam.tf`
    
    - The reason why we’re mention it here is to tell Don’t start the creation of the EKS cluster until/unless the listed policies are attached to the node.
    
    - So terraform will make the creation of the policies on the node first and then start the creation of the EKS cluster.

- The next resource is `aws_eks_node_group` named node

    - Here we’re defining not the node itself but the node group.
    - This node group has some configurations
    - Ex. all configuration, defining very few basic configurations, or the rest will be picked up the eks node itself.
    - So, we’ve already defined the cluster in this tf file but here we’re defining the worker nodes for the eks.
    - `cluster_name` you defines which cluster this node will be attached. 
    - Which in this case is `aws_eks_cluster` we had defined in the previous resource.

- Next defined the node group name which is `node_levelup`

- Next define is the node role which we had defined `eks_nodes`, we had defined this in `iam.tf`

- Next we’re defining the `subnet_ids` and here we again define the public subnets just like in the previous resource 

- Next we define the scaling capacity  
    - `scaling_config` 
    - `desired_size`
    - `max_size`
    - `min_size`
    - Remember when deciding the size of the scaling your being charged per hour for using the eks cluster + plus the type of machine your using.


- `depends_on`
    - This has three policies that we have bonded to the role we have for this resource the node role from the iam.tf.

## Deploy EKS Cluster using Terraform
• So our Terraform directory should be looking like the following.
- `vpc.tf`
- `variables.tf`
- `provider.tf`
- `iam.tf`
- `ekscluster.tf`

• With this completed we can finally begin our deployment.

•At the terminal ensure your at directory above Terraform and lets initialize our files. This will download all dependencies terraform will need to make the deployment.

- Start the initialization with:
    - `terraform init`

• After all dependecies download we can issue the planning command which will list out the deployment and all services that will be created. 

- Start the terraform plan with:
    - `terraform plan`

• You will be prompted to input your AWS user profile that you had created an aws profile with at the terminal earlier. After, inputting the user name you will be asked to put yes or no. type out `yes`

• Finally after reviewing the plan resolution you can deploy the services
- To deploy the terraform with:
    - `terraform apply`

• You will once again be prompted for the AWS user profile name, after inputting the user name you will be asked to put yes or no. type out `yes`

• It will take an approx. 15 min then stops and starts creating again, this is normal let it complete on its own. 
• You can go on to aws and check to see the services running up
- VPC 
- SG 
- EC2 
- EKS Cluster

Once its up and running you can test it via running an app on it.

## Testing the cluster

• We start back at our terminal and we need to configure our local AWS EKS 
- We do this with the following command: 
    - `aws eks --region us-east-2 update-kubeconfig --name eks_cluster_bryan` 
    - You can find your cluster name in aws console via going to Amazon EKS > clusters > select the created cluster and the cluster name will be the top or copy the name from your code, in the `ekscluster.tf`.

    - You will be prompted for the aws profile to use.

• Now that aws eks is configured locally we can now issue a deployment. We will use an nginx app to test our services.
- use the following command to create a deployment:
    - `kubectl create deployment --image=nginx nginx-app`
- We then check our deployment with:
    - `kubectl get deployments`

• Now that we have a deployment we need to expose it so we can access it since we never specified an ingress/egress in our code.
- We expose our app with the following cmd:
    - `expose deployment nginx-app --port=80 --name=nginx-http --type LoadBalancer`

- This creates a Load balancer service for which exposes the app through.

• We then check our services with the following cmd:
- `kubectl get services`

• To get more detail we can then describe our app service with this cmd:
- `kubectl describe svc nginx-http`

• Now copy `loadBalancer Ingress`and paste it on your browser and it will pull our exposed app (which will be the default nginx app page). 

• You can also verify via checking on the aws console load balancers and see if the `LoadBalancer Ingress` matches the `DNS`

## Cleaning Up
• Now that we’ve tested our code and we’re all done we can clean up our lab so we can be charged the minimal.

• First delete the resources provisioned by k8s as terraform will not clean up dependent resources and will cause trouble in terraform destroy as some services cant be deleted until their dependencies are deleted first.

• Delete the service.
- Get all available services:
`kubectl get service -o wide`

- Then you can delete any services like this (nginx-http = <YourServiceName>):
`kubectl delete svc nginx-http`

• Delete the deployment.
- `kubectl delete pod insert-name-pod`  

- Be sure to confirm the name of the pod you want to delete before pressing Enter. If you have completed the task of deleting the pod successfully, pod nginx deleted will appear in the terminal.

• Terraform clean up.
- Now that our K8s services/deployments have been cleaned up we can issue the cleanup command on terraform. Please beware of destroying AWS users with Terraform as issues have been reported that lock some admins out of their accounts.
- Terraform command:
    - `terraform destroy`
    - You will be asked to confirm type `yes`

- It will take several minutes for `terraform destroy` to complete. Ensure to review the AWS console to make sure no services are left running. Such as 
    - Network Interface for the VPC.
    - VPC 
    - SG 
    - EC2 
    - EKS Cluster 
    - Load Balancer 

## Troubleshoot

• Service got caught with trying to delete the VPC but can’t delete a VPC when it’s network interface’s were being used by the load balancer. So I had to manually delete them all.

• I ran into this issue while trying to destroy an EKS cluster after I had already deployed services onto the cluster, specifically a load balancer. 

### Solution
• Manually deleted the load balancer and the security group associated to the load balancer.
Terraform is not aware of the resources provisioned by k8s and will not clean up dependent resources.

• If you're unaware what resource may be causing the interruption of `terraform destroy`, try the following:
- `terraform apply` to get back into a good state and then use kubectl to clean up resources before running terraform destroy again.

- Below is an article that includes a script you can run to identify dependencies: https://aws.amazon.com/premiumsupport/knowledge-center/troubleshoot-dependency-error-delete-vpc/

- Review `CloudTrail logs` to see what resources were created. If this was an issue with EKS you can filter by username: `AmazonEKS`.
- Another variation of this issue is a DependencyViolation error. Ex:
    - Error deleting VPC: DependencyViolation: The vpc 'vpc-xxxxx' has dependencies and cannot be deleted. status code: 400


## License

MIT


