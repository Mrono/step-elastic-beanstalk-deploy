#!/bin/bash
set +e

cd $HOME
if [ ! -n "$WERCKER_AWS_APP_NAME" ]
then
    fail 'Missing or empty option AWS_APP_NAME, please check wercker.yml'
fi
if [ ! -n "$WERCKER_AWS_ENV_NAME" ]
then
    fail 'Missing or empty option AWS_ENV_NAME, please check wercker.yml'
fi
if [ ! -n "$WERCKER_AWS_KEY" ]
then
    fail 'Missing or empty option AWS_KEY, please check wercker.yml'
fi
if [ ! -n "$WERCKER_AWS_SECRET_KEY" ]
then
    fail 'Missing or empty option AWS_SECRET_KEY, please check wercker.yml'
fi

sudo apt-get update
sudo apt-get install unzip
wget --quiet https://s3.amazonaws.com/elasticbeanstalk/cli/AWS-ElasticBeanstalk-CLI-2.6.0.zip
unzip -qq AWS-ElasticBeanstalk-CLI-2.6.0.zip
sudo mkdir -p /usr/local/aws/elasticbeanstalk
sudo mv AWS-ElasticBeanstalk-CLI-2.6.0/* /usr/local/aws/elasticbeanstalk/
export PATH="/usr/local/aws/elasticbeanstalk/eb/linux/python2.7:$PATH"
export AWS_CREDENTIAL_FILE="/home/ubuntu/.elasticbeanstalk/aws_credential_file"
export CURRENT_BRANCH=git rev-parse --abbrev-ref HEAD
mkdir -p "/home/ubuntu/.elasticbeanstalk/"
mkdir -p "$WERCKER_SOURCE_DIR/.elasticbeanstalk/"

if [ ! -n "$CURRENT_BRANCH" ]
then
    fail 'Unable to detect current branch'
fi

export AWS_CREDENTIAL_FILE="/home/ubuntu/.elasticbeanstalk/aws_credential_file"

echo 'Setting up credentials'
echo 'AWSAccessKeyId=$WERCKER_AWS_KEY' > $AWS_CREDENTIAL_FILE
echo 'AWSSecretKey=$WERCKER_AWS_SECRET_KEY' >> $AWS_CREDENTIAL_FILE

cat <<EOT >> $WERCKER_SOURCE_DIR/.elasticbeanstalk/config
[global]
ApplicationName=$WERCKER_AWS_APP_NAME
DevToolsEndpoint=git.elasticbeanstalk.us-west-2.amazonaws.com
Region=us-west-2
ServiceEndpoint=https://elasticbeanstalk.us-west-2.amazonaws.com
EnvironmentName=$WERCKER_AWS_ENV_NAME
[branches]
$CURRENT_BRANCH=$WERCKER_AWS_ENV_NAME
[branch:$CURRENT_BRANCH]
ApplicationVersionName=$CURRENT_BRANCH
EnvironmentName=$WERCKER_AWS_ENV_NAME
InstanceProfileName=aws-elasticbeanstalk-ec2-role
EOT

if [ ! eb status ]
then
	fail 'EB is not working or is not set up correctly.'
fi

sudo bash /usr/local/aws/elasticbeanstalk/AWSDevTools/Linux/AWSDevTools-RepositorySetup.sh

if [ ! git aws.push ]
then
	fail 'Unable to push to Amazon Elastic Beanstalk'	
fi