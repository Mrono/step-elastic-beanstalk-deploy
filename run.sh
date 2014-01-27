#!/bin/bash
set +e

cd $HOME
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME" ]
then
    fail "Missing or empty option APP_NAME, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME" ]
then
    fail "Missing or empty option ENV_NAME, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY" ]
then
    fail "Missing or empty option KEY, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET" ]
then
    fail "Missing or empty option SECRET, please check wercker.yml"
fi

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    warning "Debug mode turned on, this can dump potentially dangerous information to log files."
fi

AWSEB_ROOT="$WERKER_CACHE_DIR/elasticbeanstalk"

if [ -f "$AWSEB_ROOT" ];
then
    debug "Found already existing EB file"
else
    debug "Updating apt database."
    sudo apt-get update -qq
    debug "Installing unzip."
    sudo apt-get install unzip

    debug "Installing EB."
    wget --quiet https://s3.amazonaws.com/elasticbeanstalk/cli/AWS-ElasticBeanstalk-CLI-2.6.0.zip
    unzip -qq AWS-ElasticBeanstalk-CLI-2.6.0.zip
    if [ $? -ne "0" ]
    then
        fail "Unable to unzip file.";
    fi 
    sudo mkdir -p $AWSEB_ROOT
    sudo mv AWS-ElasticBeanstalk-CLI-2.6.0/* $AWSEB_ROOT
fi

export PATH="$AWSEB_ROOT/eb/linux/python2.7:$PATH"

mkdir -p "/home/ubuntu/.elasticbeanstalk/"
mkdir -p "$WERCKER_SOURCE_DIR/.elasticbeanstalk/"
if [ $? -ne "0" ]
then
    fail "Unable to make directory.";
fi

debug "Change back to the source dir.";
cd $WERCKER_SOURCE_DIR

AWSEB_CREDENTIAL_FILE="/home/ubuntu/.elasticbeanstalk/aws_credential_file"
AWSEB_CONFIG_FILE="$WERCKER_SOURCE_DIR/.elasticbeanstalk/config"

debug "Setting up credentials."
cat <<EOT >> $AWSEB_CREDENTIAL_FILE
AWSAccessKeyId=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY
AWSSecretKey=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET
EOT

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    debug "Dumping Credential file."
    cat $AWSEB_CREDENTIAL_FILE
fi

debug "Setting up config file."
cat <<EOT >> $AWSEB_CONFIG_FILE
[global]
ApplicationName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME
DevToolsEndpoint=git.elasticbeanstalk.us-west-2.amazonaws.com
Region=us-west-2
ServiceEndpoint=https://elasticbeanstalk.us-west-2.amazonaws.com
AwsCredentialFile=$AWSEB_CREDENTIAL_FILE
EnvironmentName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
[branches]
$WERCKER_GIT_BRANCH=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
[branch:$WERCKER_GIT_BRANCH]
ApplicationVersionName=$WERCKER_GIT_BRANCH
EnvironmentName=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
InstanceProfileName=aws-elasticbeanstalk-ec2-role
EOT
if [ $? -ne "0" ]
then
    fail "Unable to set up config file."
fi

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    debug "Dumping config file."
    cat $AWSEB_CONFIG_FILE
fi

debug "Checking if eb exists and can connect."
eb status
if [ $? -ne "0" ]
then
    fail "EB is not working or is not set up correctly."
fi

sudo bash $AWSEB_ROOT/AWSDevTools/Linux/AWSDevTools-RepositorySetup.sh
if [ $? -ne "0" ]
then
    fail "Unknown error with EB tools."
fi

debug "Pushing to AWS eb servers."
git aws.push
if [ $? -ne "0" ]
then
    fail "Unable to push to Amazon Elastic Beanstalk"   
fi

success 'Successfully pushed to Amazon Elastic Beanstalk'