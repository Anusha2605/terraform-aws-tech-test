Task 1: The EC2 instance running Nginx went down over the weekend and we had an outage, it's been decided that we need a solution that is more resilient. Please implement a solution that demonstrates best practice resilience within a single region.

Solution is to deploy an autoscaling group as multi-zone. If an application running in a particulae EC2 instance goes down for some reason, the autoscaling group makes sure that it terminates the unhealthy/stopped node and launches the application again in a new EC2 instance which could be in the same zone or other.
this also helps in the scenario where an entire zone (data center) is down.

Task 2: We would like to be able to run the same stack closer to our customers in the US. Please build the same stack in the us-east-1 (Virginia) region. Note that Virginia has a different number of availability zones which we would like to take advantage of for better resilience. As for a CIDR block for the VPC use whatever you feel like, providing it's compliant with RFC-1918 and does not overlap with the dublin network.

Solution is to add a new tfvars file with details of us-east-1 region. Also the image ID or the ami should be changed here. I have parametrized this field. this value should be submitted through the tfvars file or via command line.

Task 3: We are looking to improve the security of our network and have decided we need a bastion server to avoid logging on directly to our servers. Add a bastion server, the bastion should be the only route to SSH onto servers in the VPC.

Solution is to create Bastion server in one of the subnet in the provided region and use the remaining to deploy application. Specific changes to security group needs to be added which makes sure that direct SSH to application server is not allowed.

Task 4: We are looking for a Python3 Lambda function which writes the state of the instance(s) from the previous solution to a DynamoDB table every hour, and nothing on the table should be older than a day.

Solution is to create DynamoDB with ttl (time to live) enabled. Also create a python3 lambda function which uses boto3 library and connect to ec2 and dynamodb using the respective clients, get details and update to dynamo db along with ExpiryDateTime for ttl field.

Steps to run the terraform file:
Note: terraform version used = 1.0.9
Step1:
	Create a ssh key locally using the command: ssh-keygen -t rsa
	Provide the file name along with path if necessary and save the file.
	Note down the ssh key path along with file name.

step2: 
	Clone the repository git clone https://github.com/Anusha2605/terraform-aws-tech-test.git
	Go to the root of the directory which is terraform-aws-tech-test
	Run the below commands:
		1. terraform init
		2. (for dublin region)
			tera plan -var-file=dublin.tfvars -var "public_key=<path to the public key>"
			example public key path: C:\Users\Admin\Documents\terraform-aws-tech-test\AnushaECS.pub"
			(for virginia region)
			tera plan -var-file=virginia.tfvars -var "public_key=<path to the public key>"
		3. (for dublin region)
			tera apply -var-file=dublin.tfvars -var "public_key=<path to the public key>"
			example public key path: C:\Users\Admin\Documents\terraform-aws-tech-test\AnushaECS.pub"
			(for virginia region)
			tera apply -var-file=virginia.tfvars -var "public_key=<path to the public key>"