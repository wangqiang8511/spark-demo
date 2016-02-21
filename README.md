# Introduction

This is helper scripts for Spark Group Demo 2016 Feb, Singapore.

The main purpose for these scripts is setting up mesos cluster
for demo.

However, there are plenty of existing ways to do this.

* [dcos](https://mesosphere.com/product/) for mesos eco-system bootstrap with coreos
* [mantl](https://mantl.io/) for mesos eco-system bootstrap with centos
* [playa-mesos](mesos) for mesos sandbox in vagrant.

They can achieve the same thing in a more formal way.

# Deploy the toy on local

**warning** Local deployment can only be used for bare minimum features of this demo.

The local deployment is based on virtualbox and docker-machine
These two softwares are required to be installed.

After this you can 

```bash
$ cd local

# Start all the docker machines and bootstrap
$ ./deploy_dm.sh bootstrap

# Remove all the docker machines
$ ./deploy_dm.sh teardown
```

After you create the env, you can

* Get the ip of mesos-master by 

```bash
docker-machine ip mesos-master
```

* Access "http://$YOUR\_MASTER\_IP:5050"

# Deploy the toy on aws

* Find the correct ubuntu image with [ami finder](https://cloud-images.ubuntu.com/locator/ec2/)
* Prepare your ssh keys (pem and pub files). Put rename them to be spark.pem and spark.pub in aws folder. 
* Create an instance profile (IAM role) with s3 read/write permission.
* Create s3 bucket for exhibitor config sync.

After this you can 

```bash
$ cd aws

$ cp infra.sample.yml infra.yml
# Modify infra.yml accordingly (The s3 bucket your created)

$ cp terraform/aws.tf.tmpl aws.tf
# Modify accordingly (ami, credentials, instance profile)

# Start all the instances and bootstrap
$ ./deploy_aws.sh bootstrap

# Remove all instances
$ ./deploy_aws.sh teardown
```

In the bootstrap script,

* [terraform](https://www.terraform.io/) is used for creating the aws resources for this demo.
* [ansible](https://www.ansible.com/) is used for provisioning.

After you create the env, you can

* Get one of the masters's ip

```bash
ansible -m debug -a "var=hostvars['spark-master-001']['public_ipv4']" spark-master-001
ansible -m debug -a "var=hostvars['spark-master-001']['private_ipv4']" spark-master-001
```

* SSH to your master and create tunnel

```bash
ssh -i spark.pem ubuntu@$YOUR_MASTER_PUBLIC_IP -D 8108
```

* Use Foxy Proxy to access your infra in aws "http://$YOUR\_MASTER\_PRIVATE\_IP:5050"

# Deploy the toy on other cloud platforms.

I didn't tried.
But terraform has all the providers.

# Marathon script

TODO

# Email Me

[Wang Qiang](mailto:wangqiang8511@gmail.com)
