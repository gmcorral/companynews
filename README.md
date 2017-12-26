# ThoughtWorks Company News assignment

## PROJECT DESCRIPTION

Project contains the following deliverables:

- deploy.sh: stack deploy script
- doc:
  - deployment.pdf: deployment manual
  - project.pdf: approach description, architecture design and scaling plan document
- infrastructure: infrastructure templates folder
- README.md: this file
- services:
  - companynews: companyNews application Dockerfile
  - static: static files server Dockerfile

## AWS CREDENTIALS

AWS credentials must be provided (via .aws config file or environment variables) so the project can be deployed on EC2 instances:

- AWS_DEFAULT_REGION: us-east-1
- AWS_ACCESS_KEY_ID: <AWS_ACCESS_KEY_ID>
- AWS_SECRET_ACCESS_KEY: <AWS_SECRET_ACCESS_KEY>
