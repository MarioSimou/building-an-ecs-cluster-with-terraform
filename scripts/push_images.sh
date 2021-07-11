# /bin/bash

# Author: Marios Simou
# Description: Script to pull image from public docker hub and push them to an aws registry. The aws registry should be passed
# as an argument. If not, the script will error. The script assumes that the aws repositories have already been created and the user
# logged to aws. If not, run the following command:
# 
# AWS Login:
# aws get-login-password | docker login -u AWS --password-stdin [AWS_REGISTRY]
# 
# Example:
# ./push_images [AWS_ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com

set -e

docker_images=("msimou/server" "msimou/helloworld")
aws_images=("mariossimou-dev-web" "mariossimou-dev-hello")
registry=$1

if [[ ! $registry =~ ".amazonaws.com" ]]; then
    printf "Registry value is '%s'. Please provide a valid value.\n" $registry
    exit 1
fi

size=${#docker_images[@]}

for ((i=0; i < $size; i++)); do
    docker_image=${docker_images[$i]}
    aws_image=${aws_images[$i]}
    target_registry="${registry}/${aws_image}"

    docker pull $docker_image
    docker tag $docker_image $target_registry
    docker push $target_registry    
done

exit 0