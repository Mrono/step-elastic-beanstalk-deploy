#!/bin/bash
set +e

cd $HOME
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME" ]
then
    fail 'Missing or empty option APP_NAME, please check wercker.yml'
fi
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME" ]
then
    fail 'Missing or empty option ENV_NAME, please check wercker.yml'
fi
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY" ]
then
    fail 'Missing or empty option KEY, please check wercker.yml'
fi
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET_KEY" ]
then
    fail 'Missing or empty option SECRET_KEY, please check wercker.yml'
fi

echo '-----Updating apt database'
sudo apt-get update -qq
echo '-----Installing unzip'
sudo apt-get install unzip

echo '-----Installing EB'
wget --quiet https://s3.amazonaws.com/elasticbeanstalk/cli/AWS-ElasticBeanstalk-CLI-2.6.0.zip
unzip -qq AWS-ElasticBeanstalk-CLI-2.6.0.zip
if [[ $? -ne "0" ]]; 
then
    fail "Unable to unzip file";
fi 
sudo mkdir -p /usr/local/aws/elasticbeanstalk
sudo mv AWS-ElasticBeanstalk-CLI-2.6.0/* /usr/local/aws/elasticbeanstalk/

export PATH="/usr/local/aws/elasticbeanstalk/eb/linux/python2.7:$PATH"
export AWS_CREDENTIAL_FILE="/home/ubuntu/.elasticbeanstalk/aws_credential_file"

mkdir -p "/home/ubuntu/.elasticbeanstalk/"
mkdir -p "$WERCKER_SOURCE_DIR/.elasticbeanstalk/"
if [[ $? -ne "0" ]];
then
    fail "Unable to make directory";
fi 

echo '-----Change back to the source dir';
cd $WERCKER_SOURCE_DIR

export AWS_CREDENTIAL_FILE="$WERCKER_SOURCE_DIR/.elasticbeanstalk/aws_credential_file"

echo '-----Setting up credentials'
cat <<EOT >> $AWS_CREDENTIAL_FILE
AWSAccessKeyId=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY
AWSSecretKey=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET_KEY
EOT

echo '-----Setting up config file'
cat <<EOT >> $WERCKER_SOURCE_DIR/.elasticbeanstalk/config
[global]
ApplicationName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME
DevToolsEndpoint=git.elasticbeanstalk.us-west-2.amazonaws.com
Region=us-west-2
ServiceEndpoint=https://elasticbeanstalk.us-west-2.amazonaws.com
AwsCredentialFile=$AWS_CREDENTIAL_FILE
EnvironmentName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
[branches]
$WERCKER_GIT_BRANCH=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
[branch:$WERCKER_GIT_BRANCH]
ApplicationVersionName=$WERCKER_GIT_BRANCH
EnvironmentName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
InstanceProfileName=aws-elasticbeanstalk-ec2-role
EOT
if [[ $? -ne "0" ]];
then
	fail 'Unable to set up config file.'
fi

echo '-----Checking if eb exists and can connect'
eb status
if [[ $? -ne "0" ]];
then
	fail 'EB is not working or is not set up correctly.'
fi

sudo bash /usr/local/aws/elasticbeanstalk/AWSDevTools/Linux/AWSDevTools-RepositorySetup.sh
if [[ $? -ne "0" ]];
then
	fail 'Unknown error with EB tools.'
fi

echo '-----Pushing to AWS eb servers'
git aws.push
if [[ $? -ne "0" ]];
then
	fail 'Unable to push to Amazon Elastic Beanstalk'	
fi