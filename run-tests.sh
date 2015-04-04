#Bash strict mode http://redsymbol.net/articles/unofficial-bash-strict-mode/
#This means the script will fail as soon anything fails
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#Test inspired by https://servercheck.in/blog/testing-ansible-roles-travis-ci-github

DOCKER_IMAGE="tutum/centos:centos7"
SSH_PUBLIC_KEY_FILE=~/.ssh/id_rsa.pub
SSH_PUBLIC_KEY=`cat "$SSH_PUBLIC_KEY_FILE"`
DOCKER_CONTAINER_NAME="centos7-for-ansible-role-test"

function startDockerContainer {
    echo "Stop any running docker containers of the name $DOCKER_CONTAINER_NAME"
    docker stop $DOCKER_CONTAINER_NAME || true
    docker rm $DOCKER_CONTAINER_NAME || true
    echo "Starting docker container... "
    docker run --name $DOCKER_CONTAINER_NAME -d -p 5555:22 -e AUTHORIZED_KEYS="$SSH_PUBLIC_KEY" $DOCKER_IMAGE
}

function testRoleInstalledFileAsExpected {
    echo "check config was actually installed"
    docker exec  $DOCKER_CONTAINER_NAME cat /etc/important-config.conf
}

function testRoleCanBeAppliedToDockerContainer {
    echo "Test role can be applied to docker container"
    ansible-playbook -i test/inventory test/test.yml
}

function testRoleSyntax {
    echo "Test role sytax locally"
    ansible-playbook -i test/inventory test/test.yml --syntax-check
}

function testForIdempotence {
    echo "Test for idempotence.  Run playbook again, should result in zero changes."
    ANSIBLE_OUTPUT=`ansible-playbook -i test/inventory test/test.yml  || true`
    echo $ANSIBLE_OUTPUT
    [[ $ANSIBLE_OUTPUT =~ changed=0.*unreachable=0.*failed=0 ]] && echo "Idempotence Test Passed" || echo "Idempotence Test Failed" && exit 1
}

testRoleSyntax

startDockerContainer

testRoleCanBeAppliedToDockerContainer

testForIdempotence

testRoleInstalledFileAsExpected

echo "All Tests Passed"