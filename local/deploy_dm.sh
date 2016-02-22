#!/bin/bash

set -e

MASTER_TARGET=mesos-master
SLAVE_TARGET_PREFIX=mesos-slave
SLAVE_SIZE=2
MASTER_MEMORY_SIZE=4096
SLAVE_MEMORY_SIZE=2048

function teardown {
  docker-machine rm $MASTER_TARGET

  for (( c=0; c<$SLAVE_SIZE; c++ ))
  do
  docker-machine rm $SLAVE_TARGET_PREFIX$c
  done
}

function create-mesos-master-machine {
  echo "creating docker machine $MASTER_TARGET"
  docker-machine create \
    -d virtualbox \
    --virtualbox-memory "$MASTER_MEMORY_SIZE" \
    --virtualbox-cpu-count "2" \
    $MASTER_TARGET
}

function create-mesos-slave-machine {
  echo "creating docker machine $SLAVE_TARGET_PREFIX$1"
  docker-machine create \
    -d virtualbox \
    --virtualbox-memory "$SLAVE_MEMORY_SIZE" \
    --virtualbox-cpu-count "2" \
    $SLAVE_TARGET_PREFIX$1
}

function create-mesos-slave-machines {
  for (( c=0; c<$SLAVE_SIZE; c++ ))
  do
  create-mesos-slave-machine $c 
  done
}

function update-etc-hosts {
  IP=$(docker-machine ip $1)
  docker-machine ssh $1 "sudo sed -i 's/^127\.0\.0\.1 "$1"/127.0.0.1/g' /etc/hosts"
  docker-machine ssh $1 "sudo sh -c 'echo "$IP $1" >> /etc/hosts'"
}

function update-all-etc-hosts {
  update-etc-hosts $MASTER_TARGET
  for (( c=0; c<$SLAVE_SIZE; c++ ))
  do
    update-etc-hosts $SLAVE_TARGET_PREFIX$c
  done
}

function activate-target {
  TARGET_MACHINE=$1
  eval "$(docker-machine env $TARGET_MACHINE)"
}

function start-zk {
  echo "starting zookeeper on $MASTER_TARGET"
  activate-target $MASTER_TARGET

  docker run -d \
    -e MYID=1 \
    --name=zookeeper \
    --net=host \
    --restart=always \
    mesoscloud/zookeeper:3.4.6-ubuntu-14.04
}

function start-mesos-master {
  echo "starting mesos-master on $MASTER_TARGET"
  activate-target $MASTER_TARGET
  MASTER_IP=$(docker-machine ip $MASTER_TARGET)

  docker run -d \
    --name mesos-master \
    --net host \
    --restart always \
    mesosphere/mesos-master:0.27.0-0.2.190.ubuntu1404 \
    --zk=zk://localhost:2181/mesos \
    --work_dir=/var/lib/mesos/master \
    --quorum=1 \
    --hostname=$MASTER_IP\
    --ip=$MASTER_IP\
    --no-hostname_lookup \
    --cluster=mesostest
}

function start-marathon {
  echo "starting marathon on $MASTER_TARGET"
  activate-target $MASTER_TARGET
  MASTER_IP=$(docker-machine ip $MASTER_TARGET)

  docker run -d \
    --name marathon \
    --net host \
    --restart always \
    mesosphere/marathon:v0.15.1 \
    --master zk://localhost:2181/mesos \
    --zk zk://localhost:2181/marathon \
    --hostname $MASTER_IP
}

function start-chronos {
  echo "starting chronos on $MASTER_TARGET"
  activate-target $MASTER_TARGET
  MASTER_IP=$(docker-machine ip $MASTER_TARGET)

  docker run -d \
    --name chronos \
    --net host \
    --restart always \
    mesosphere/chronos:chronos-2.4.0-0.1.20150828104228.ubuntu1404-mesos-0.27.0-0.2.190.ubuntu1404 \
    /usr/bin/chronos run_jar \
    --master zk://localhost:2181/mesos \
    --zk_hosts localhost:2181 \
    --http_port 8081 \
    --hostname $MASTER_IP
}

function start-mesos-slave {
  TARGET_MACHINE=$SLAVE_TARGET_PREFIX$1
  echo "starting mesos-slave on $TARGET_MACHINE"
  CURRENT_IP=$(docker-machine ip $TARGET_MACHINE)
  MASTER_IP=$(docker-machine ip $MASTER_TARGET)
  activate-target $TARGET_MACHINE

  docker run -d \
    --name mesos-slave \
    --privileged \
    --net host \
    --restart always \
    -v /usr/local/bin/docker:/usr/bin/docker:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:rw \
    -v /sys:/sys:ro \
    mesosphere/mesos-slave:0.27.0-0.2.190.ubuntu1404 \
    --master=zk://$MASTER_IP:2181/mesos \
    --hostname=$CURRENT_IP \
    --ip=$CURRENT_IP \
    --no-hostname_lookup \
    --containerizers=docker,mesos
}

function start-mesos-slaves {
  for (( c=0; c<$SLAVE_SIZE; c++ ))
  do
    start-mesos-slave $c
  done
}

function pull-spark-image {
  docker-machine ssh $MASTER_TARGET \
    "docker pull wangqiang8511/spark-mesos:1.6.0-0.27.0"
  for (( c=0; c<$SLAVE_SIZE; c++ ))
  do
    docker-machine ssh $SLAVE_TARGET_PREFIX$c \
      "docker pull wangqiang8511/spark-mesos:1.6.0-0.27.0"
  done
}

function bootstrap {
  create-mesos-master-machine
  create-mesos-slave-machines
  start-zk
  start-mesos-master
  start-marathon
  start-chronos
  start-mesos-slaves
  update-all-etc-hosts
  pull-spark-image
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
