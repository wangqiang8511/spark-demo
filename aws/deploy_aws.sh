#!/bin/bash

set -e

function bootstrap-cluster {
  terraform get
  terraform plan
  terraform apply
}

function provisioning-cluster {
  ansible-playbook mesos.yml -e @infra.yml -vvv
}

function teardown-cluster {
  terraform destroy
}

function bootstrap {
  bootstrap-cluster
  sleep 60
  provisioning-cluster
}

function teardown {
  teardown-cluster
}

if [ X$1 == "Xteardown" ]
then
  teardown
elif [ X$1 == "Xbootstrap" ]
then
  bootstrap
else
  echo "Need command like teardown|bootstrap"
fi
