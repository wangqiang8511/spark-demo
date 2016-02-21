#!/usr/bin/env sh

render_template() {
  eval "echo \"$(cat $1)\""
}

SPARK_HOME=${SPARK_HOME:-/usr/local/spark}
SPARK_MASTER=${SPARK_MASTER:-local}
ROOT_LOG_LEVEL=${ROOT_LOG_LEVEL:-WARN}
MESOS_EXECUTOR_CORE=${MESOS_EXECUTOR_CORE:-0.1}
HIVE_METASTORE_HOST=${HIVE_METASTORE_HOST:-}
HIVE_METASTORE_PORT=${HIVE_METASTORE_PORT:-9083}
SPARK_IMAGE=${SPARK_IMAGE}
CURRENT_IP=$(hostname -i)

# render hive-site.xml if HIVE_METASTORE is defined
if [ $HIVE_METASTORE_HOST ];
then
  render_template $SPARK_HOME/conf/hive-site.xml.template > $SPARK_HOME/conf/hive-site.xml
fi

cat > $SPARK_HOME/conf/spark-env.sh << EOF
#!/usr/bin/env bash
export MESOS_NATIVE_JAVA_LIBRARY=${MESOS_NATIVE_JAVA_LIBRARY:-/usr/lib/libmesos.so}
EOF
chmod =x $SPARK_HOME/conf/spark-env.sh


cat > $SPARK_HOME/conf/spark-defaults.conf << EOF
spark.master                      $SPARK_MASTER
spark.mesos.mesosExecutor.cores   $MESOS_EXECUTOR_CORE
spark.mesos.executor.docker.image $SPARK_IMAGE
spark.mesos.executor.home        $SPARK_HOME
spark.driver.host $CURRENT_IP
spark.executor.extraClassPath  $SPARK_HOME/extra_jars/*
spark.driver.extraClassPath  $SPARK_HOME/extra_jars/*
EOF

cat > $SPARK_HOME/conf/log4j.properties << EOF

# Set everything to be logged to the console
log4j.rootCategory=$ROOT_LOG_LEVEL, console
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p %c{1}: %m%n

# Settings to quiet third party logs that are too verbose
log4j.logger.org.spark-project.jetty=WARN
log4j.logger.org.spark-project.jetty.util.component.AbstractLifeCycle=ERROR
log4j.logger.org.apache.spark.repl.SparkIMain\$exprTyper=INFO
log4j.logger.org.apache.spark.repl.SparkILoop\$SparkILoopInterpreter=INFO
log4j.logger.org.apache.parquet=ERROR
log4j.logger.parquet=ERROR

# SPARK-9183: Settings to avoid annoying messages when looking up nonexistent UDFs in SparkSQL with Hive support
log4j.logger.org.apache.hadoop.hive.metastore.RetryingHMSHandler=FATAL
log4j.logger.org.apache.hadoop.hive.ql.exec.FunctionRegistry=ERROR

EOF

if [ $ADDITIONAL_VOLUMES ];
then
    echo "spark.mesos.executor.docker.volumes: $ADDITIONAL_VOLUMES" >> $SPARK_HOME/conf/spark-defaults.conf
fi

exec "$@"
