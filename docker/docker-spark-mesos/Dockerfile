FROM ipython/scipystack

ENV DEBIAN_FRONTEND noninteractive
ENV SPARK_HOME /usr/local/spark

# install pip
RUN curl -s https://bootstrap.pypa.io/get-pip.py | python

# Install ipython
RUN pip install ipython

RUN mkdir /scripts

# install mesos
COPY scripts/setup_mesos_repo.sh /scripts
RUN sh /scripts/setup_mesos_repo.sh
RUN apt-get -y update && apt-get install -y --force-yes mesos=0.27.0-0.2.190.ubuntu1404


# install and configurate spark
RUN curl http://www.us.apache.org/dist/spark/spark-1.6.0/spark-1.6.0-bin-hadoop2.6.tgz -o /tmp/spark-1.6.0-bin-hadoop2.6.tgz \
    && tar -xzf /tmp/spark-1.6.0-bin-hadoop2.6.tgz -C /usr/local/ \
    && ln -s /usr/local/spark* /usr/local/spark \
    && rm -f /tmp/spark-1.6.0-bin-hadoop2.6.tgz

COPY scripts/get_extra_jars.sh /scripts/get_extra_jars.sh
RUN mkdir /usr/local/spark/extra_jars
RUN bash /scripts/get_extra_jars.sh

VOLUME /notebooks
WORKDIR /notebooks

COPY conf/spark-env.sh /usr/local/spark/conf/spark-env.sh
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
COPY scripts/mesos_run.sh /scripts/mesos_run.sh

ENTRYPOINT ["/scripts/mesos_run.sh"]
