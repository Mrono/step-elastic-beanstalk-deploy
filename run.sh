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

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION" ]
then
    warn "Missing or empty option REGION, defaulting to us-west-2"
    WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION="us-west-2"
fi

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    warn "Debug mode turned on, this can dump potentially dangerous information to log files."
fi

AWSEB_ROOT="$WERCKER_STEP_ROOT/eb-tools"
AWSEB_TOOL="$AWSEB_ROOT/eb/linux/python2.7/eb"

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
AWSEB_DEVTOOLS_ENDPOINT="git.elasticbeanstalk.$WERCKER_STEP_EBS_DEPLOY_REGION.amazonaws.com"
AWSEB_SERVICE_ENDPOINT="https://elasticbeanstalk.$WERCKER_STEP_EBS_DEPLOY_REGION.amazonaws.com"

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
DevToolsEndpoint=$AWSEB_DEVTOOLS_ENDPOINT
Region=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION
ServiceEndpoint=$AWSEB_SERVICE_ENDPOINT
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
$AWSEB_TOOL status
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
