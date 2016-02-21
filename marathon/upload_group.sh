#!/bin/bash

# Upload artifacts to marathon
MARATHON_MASTER=${MARATHON_MASTER:-"http://127.0.0.1:8080"}

curl -include -XPUT "$MARATHON_MASTER/v2/groups" -d @$1
