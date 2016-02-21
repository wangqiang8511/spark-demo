#!/bin/bash 

SPARK_IMAGE="wangqiang8511/spark-mesos:1.6.0-0.27.0"
MASTER_TARGET="mesos-master"
MASTER_IP=$(docker-machine ip $MASTER_TARGET)
SPARK_MASTER="mesos://zk://${MASTER_IP}:2181/mesos"

eval $(docker-machine env $MASTER_TARGET)

docker run -it --rm \
  -e SPARK_MASTER=${SPARK_MASTER} \
  -e SPARK_IMAGE=${SPARK_IMAGE} \
	-e PYSPARK_DRIVER_PYTHON=ipython2 \
  -e PYSPARK_DRIVER_PYTHON_OPTS="notebook --ip='*' --port=8888" \
  --net=host \
  $SPARK_IMAGE /scripts/mesos_run.sh sh -c "/usr/local/spark/bin/pyspark \
  --conf spark.mesos.coarse=true \
	--conf spark.executor.memory=512m \
  --conf spark.driver.host=$MASTER_IP \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.sql.parquet.output.committer.class=org.apache.spark.sql.parquet.DirectParquetOutputCommitter \
  --conf spark.shuffle.spill=true"
