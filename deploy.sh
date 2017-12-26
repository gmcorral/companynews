#!/bin/bash


###########################
# setup parameters

# command line params
ENV=$1
if [ -z "$ENV" ]; then
    echo "Usage: deploy.sh <env>"
    echo "         - env: training|production"
    exit 1
fi

# EC2 params
INSTANCE_TYPE=t2.micro

# docker params
COMPANYNEWS_IMAGE_NAME=thoughtworks/companynews
STATIC_IMAGE_NAME=thoughtworks/static

# cloudformation params
CF_TEMPLATES_DIR=infrastructure
CF_TEMPLATES_BUCKET=thoughtworks-companynews-code
CF_TEMPLATES_URL=https://s3.amazonaws.com/$CF_TEMPLATES_BUCKET
CF_TEMPLATES_URI=s3://$CF_TEMPLATES_BUCKET
CF_STACK_NAME=companynews-$ENV


###########################
# check SW requirements

AWS_CLI=$(which aws)
DOCKER_CLI=$(which docker)

if [ -z "$AWS_CLI" ]; then

    echo "AWS CLI not found on local machine, installing.."

    sudo apt-get update
    sudo apt-get install python-pip python-dev build-essential
    sudo pip install --upgrade pip
    pip install awscli --upgrade --user

    AWS_CLI=$(which aws)
    if [ -z "$AWS_CLI" ]; then
        echo " ** ERROR: couldn't install AWS CLI"
        exit 1
    fi
fi

if [ -z "$DOCKER_CLI" ]; then

    echo "Docker CLI not found on local machine, installing.."

    sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    sudo apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
    sudo apt-get update
    apt-cache policy docker-engine
    sudo apt-get install -y docker-engine
    sudo usermod -aG docker $(whoami)

    DOCKER_CLI=$(which docker)
    if [ -z "$AWS_CLI" ]; then
        echo " ** ERROR: couldn't install Docker CLI"
        exit 1
    fi
fi


echo ""
echo " *********************************************"
echo " ** CompanyNews $ENV environment deployment"
echo " *********************************************"
echo ""


function upload_dir(){

    pushd $1 > /dev/null || return 
    DIR_OK=0

    for t in *'.json'
    do
        DEST=$2/$t
        echo " - Uploading $t to $DEST"
        $AWS_CLI s3 cp $t $DEST > /dev/null
        if [ $? -eq 0 ]; then
            echo "   OK"
        else
            echo " ** ERROR: Uploading template $t"
            DIR_OK=1
        fi
    done

    popd > /dev/null
    return $DIR_OK
}


###########################
# ECR registry

# login to ECS docker registry

echo " ** [1/10] Logging in to docker registry"
eval $($AWS_CLI ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
if [[ $? -gt 0 ]]; then echo " ** ERROR logging in to docker registry"; exit 1; fi

# create ECR repositories
COMPANYNEWS_ECR=$($AWS_CLI ecr describe-repositories --repository-names $COMPANYNEWS_IMAGE_NAME --region $AWS_DEFAULT_REGION | jq -r ".repositories[0].repositoryUri")
if [[ "$COMPANYNEWS_ECR" == "" ]]; then
    echo "  Creating $COMPANYNEWS_IMAGE_NAME repository"
    $AWS_CLI ecr create-repository --repository-name $COMPANYNEWS_IMAGE_NAME --region $AWS_DEFAULT_REGION
    COMPANYNEWS_ECR=$($AWS_CLI ecr describe-repositories --repository-names $COMPANYNEWS_IMAGE_NAME --region $AWS_DEFAULT_REGION | jq -r ".repositories[0].repositoryUri")
fi

STATIC_ECR=$($AWS_CLI ecr describe-repositories --repository-names $STATIC_IMAGE_NAME --region $AWS_DEFAULT_REGION | jq -r ".repositories[0].repositoryUri")
if [[ "$STATIC_ECR" == "" ]]; then
    echo "  Creating $STATIC_IMAGE_NAME repository"
    $AWS_CLI ecr create-repository --repository-name $STATIC_IMAGE_NAME --region $AWS_DEFAULT_REGION
    STATIC_ECR=$($AWS_CLI ecr describe-repositories --repository-names $STATIC_IMAGE_NAME --region $AWS_DEFAULT_REGION | jq -r ".repositories[0].repositoryUri")
fi


###########################
# CompanyNews docker image

# build CompanyNews docker image
echo " ** [2/10] Building CompanyNews docker image.."
$DOCKER_CLI build -t $COMPANYNEWS_IMAGE_NAME:$ENV services/companynews
if [[ $? -gt 0 ]]; then echo " ** ERROR building CompanyNews docker image"; exit 1; fi

# tag image and upload to registry
echo " ** [3/10] Tagging CompanyNews image.."
$DOCKER_CLI tag $COMPANYNEWS_IMAGE_NAME:$ENV $COMPANYNEWS_ECR:$ENV
if [[ $? -gt 0 ]]; then echo " ** ERROR tagging CompanyNews docker image"; exit 1; fi

echo " ** [4/10] Pushing CompanyNews image.."
$DOCKER_CLI push $COMPANYNEWS_ECR
if [[ $? -gt 0 ]]; then echo " ** ERROR pushing CompanyNews docker image"; exit 1; fi


###########################
# Static docker image

# build static docker image
echo " ** [5/10] Building static docker image.."
$DOCKER_CLI build -t $STATIC_IMAGE_NAME:$ENV services/static
if [[ $? -gt 0 ]]; then echo " ** ERROR building static docker image"; exit 1; fi

# tag image and upload to registry
echo " ** [6/10] Tagging static image.."
$DOCKER_CLI tag $STATIC_IMAGE_NAME:$ENV $STATIC_ECR:$ENV
if [[ $? -gt 0 ]]; then echo " ** ERROR tagging static docker image"; exit 1; fi

echo " ** [7/10] Pushing static image.."
$DOCKER_CLI push $STATIC_ECR
if [[ $? -gt 0 ]]; then echo " ** ERROR pushing static docker image"; exit 1; fi


###########################
# Cloudformation stack

# upload cloudformation templates to S3
echo " ** [8/10] Uploading Cloudformation templates to S3.."
$AWS_CLI s3api head-bucket --bucket $CF_TEMPLATES_BUCKET --region $AWS_DEFAULT_REGION > /dev/null
if [[ $? -gt 0 ]]; then
    echo "  Creating $CF_TEMPLATES_BUCKET bucket";
    $AWS_CLI s3api create-bucket --bucket $CF_TEMPLATES_BUCKET; 
fi

upload_dir $CF_TEMPLATES_DIR $CF_TEMPLATES_URI
if [[ $? -gt 0 ]]; then echo " ** ERROR uploading Cloudformation templates to S3"; exit 1; fi

# deploy Cloudformation template
echo " ** [9/10] Creating Cloudformation stack.."
$AWS_CLI cloudformation create-stack --stack-name $CF_STACK_NAME --template-url $CF_TEMPLATES_URL/companynews.json --region $AWS_DEFAULT_REGION --parameters \
    ParameterKey=Environment,ParameterValue=$ENV,UsePreviousValue=true \
    ParameterKey=InstanceType,ParameterValue=$INSTANCE_TYPE,UsePreviousValue=true \
    ParameterKey=CompanyNewsECR,ParameterValue=$COMPANYNEWS_ECR,UsePreviousValue=true \
    ParameterKey=StaticECR,ParameterValue=$STATIC_ECR,UsePreviousValue=true \
    --capabilities CAPABILITY_NAMED_IAM
if [[ $? -gt 0 ]]; then echo " ** ERROR creating Cloudformation stack"; exit 1; fi

# wait for completion
echo " ** Waiting for resources creation. This process can take several minutes"
$AWS_CLI cloudformation wait stack-create-complete --stack-name $CF_STACK_NAME
if [[ $? -gt 0 ]]; then echo " ** ERROR creating Cloudformation stack"; exit 1; fi

# retrieve output values
echo " ** [10/10] Obtaining resource URLs.."
COMPANYNEWS_URL=$($AWS_CLI cloudformation describe-stacks --stack-name $CF_STACK_NAME | jq -r ".Stacks[0].Outputs[] | select(.OutputKey==\"CompanyNewsURL\").OutputValue")
if [[ $? -gt 0 ]]; then echo " ** ERROR obtaining stack output values"; exit 1; fi

echo " ** Cloudformation stack successfully created"

echo " ********************************************************"
echo " ** "
echo " ** You can access CompanyNews app using the following URL:"
echo " ** "
echo ""
echo "$COMPANYNEWS_URL"
echo ""
echo " ********************************************************"

exit 0