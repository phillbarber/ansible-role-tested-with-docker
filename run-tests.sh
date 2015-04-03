#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#Bash strict mode http://redsymbol.net/articles/unofficial-bash-strict-mode/
#This means the script will fail as soon anything fails


#Test inspired by https://servercheck.in/blog/testing-ansible-roles-travis-ci-github
DOCKER_IMAGE="tutum/centos:centos7"
ROLE_DIRECTORY="$PWD"
SSH_PUBLIC_KEY_FILE=~/.ssh/id_rsa.pub
SSH_PUBLIC_KEY=`cat "$SSH_PUBLIC_KEY_FILE"`
DOCKER_CONTAINER_NAME="centos7-for-ansible-role-test"

echo "Test role sytax locally"
ansible-playbook -i test/inventory test/test.yml --syntax-check --extra-vars "ROLE_DIRECTORY=$ROLE_DIRECTORY"

echo "Stop any running docker containers of the name $DOCKER_CONTAINER_NAME"
docker stop $DOCKER_CONTAINER_NAME || true
docker rm $DOCKER_CONTAINER_NAME || true

echo "Starting docker container... "
docker run --name $DOCKER_CONTAINER_NAME -d -p 5555:22 -e AUTHORIZED_KEYS="$SSH_PUBLIC_KEY" $DOCKER_IMAGE

echo "Test role can be applied"
ansible-playbook -i test/inventory test/test.yml --extra-vars "ROLE_DIRECTORY=$ROLE_DIRECTORY"

echo "Test for idempotence.  Run playbook again, should result in zero changes (i.e. idempotence test)"

# || true means don't fail on errors for the 2nd run
ANSIBLE_OUTPUT=`ansible-playbook -i test/inventory test/test.yml --extra-vars "ROLE_DIRECTORY=$ROLE_DIRECTORY" || true`

echo $ANSIBLE_OUTPUT

[[ $ANSIBLE_OUTPUT =~ changed=0.*unreachable=0.*failed=0 ]] && echo "Idempotence Test Passed" || echo "Idempotence Test Failed" exit 1

echo "check config was actually installed"
docker exec  $DOCKER_CONTAINER_NAME cat /etc/important-config.conf
echo "All Tests Passed"