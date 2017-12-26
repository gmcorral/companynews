******************
***** README *****
******************


1. PROJECT DESCRIPTION
----------------------

Project contains the following deliverables:

	- deploy.sh: stack deploy script
	- deployment.pdf: deployment manual
	- infrastructure: infrastructure templates
	- project.pdf: approach description, architecture design and scaling plan document
	- readme.txt: this file
	- services:
		- companynews: companyNews application Dockerfile
		- static: static files server Dockerfile


2. AWS CREDENTIALS
------------------

AWS credentials must be provided (via .aws config file or environment variables) so the project can be deployed on EC2 instances:

	- AWS_DEFAULT_REGION: us-east-1
	- AWS_ACCESS_KEY_ID: <AWS_ACCESS_KEY_ID>
	- AWS_SECRET_ACCESS_KEY: <AWS_SECRET_ACCESS_KEY>


3. POSSIBLE IMPROVEMENTS
------------------------

Due to time and scope constraints, the following improvements were not addressed:

	- Enforce HTTPS on the Load Balancer using a certificate
	- Use a custom open source load balancer, such as HAProxy, instead of the AWS ALB
	- Use custom domains for each application environment, configured via Route53
