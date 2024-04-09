#!/bin/bash

KAFKA_HOME="<path-to-kafka>"

if [[ "$#" < "1" ]] || [[ "$1" == *"help"* ]] || [[ "$1" == "-h" ]]; then
  echo "
Usage: $0 <START|STOP|INITIALIZE|START_CLUSTER|STOP_CLUSTER> <KAFKA|ZOOKEEPER|ALL> <NODE_NAME>
1st option:
   - START         : Start any process
   - STOP          : Stop any process
   - INITIALIZE    : Initialize property file
   - START_CLUSTER : Start zookeeper, start kafka server on all nodes.
   - STOP_CLUSTER  : Stop zookeeper, start kafka server on all nodes.

2nd option: No need to use this option while using START_CLUSTER and STOP_CLUSTER
  - KAFKA         : Start any process
  - ZOOKEEPER     : Stop any process
  - ALL           : Initialize property file

3rd option: No need to use this option while using START_CLUSTER and STOP_CLUSTER
  - Which node you would like to start particular process
"
  exit 0
fi

srun_process_cmd() {  
  srun -O -N1 -n1 --overlap --cpus-per-task=$SLURM_CPUS_PER_TASK --mem=0 --nodelist=$1 /bin/bash -c "$2 & wait \$!" &
}

module load Java

# What operation needs to be performed
# Options:
#   - START         : Start any process
#   - STOP          : Stop any process
#   - INITIALIZE    : Initialize property file
#   - START_CLUSTER : Start zookeeper, start kafka server on all nodes.
#   - STOP_CLUSTER  : Stop zookeeper, start kafka server on all nodes.
MODE="$1"

# What process needs to started stopped
# Options:
#   - KAFKA         : Start any process
#   - ZOOKEEPER     : Stop any process
#   - ALL           : Initialize property file
PROCESS="$2"
if [[ "$MODE" == *"CLUSTER" ]]; then
  PROCESS="ALL"
fi

NODE_NAME="$3"
if [[ "x$NODE_NAME" == "x" ]]; then
  NODE_LIST=$(scontrol show hostname $SLURM_NODELIST)
else
  NODE_LIST="$NODE_NAME"
fi

if [[ "$PROCESS" == "ZOOKEEPER" ]]; then
  ZK_NODE="$NODE_NAME"
else
  # Always start zookeeper on alphabetically first node
  ZK_NODE=$(scontrol show hostname $SLURM_NODELIST | head -1)
fi

# Initialize broker id and port
BROKER_ID_i=0
BROKER_PORT_i=9092

KAFKA_CONF_DIR="${KAFKA_CONF_DIR:-$KAFKA_HOME/config}"

# Slurm job time
job_time="$((SLURM_JOB_END_TIME-SLURM_JOB_START_TIME))s"

if [[ "$MODE" == "START"* ]]; then

  # Starting Zookeeper
  if [[ "$PROCESS" =~ ^(ZOOKEEPER|ALL)$ ]]; then
    srun_process_cmd "$ZK_NODE" "nohup $KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties"
  fi

  # Starting Kafka  
  if [[ "$PROCESS" =~ ^(KAFKA|ALL|INITIALIZE)$ ]]; then
    # Create corresponding server.properties file and zookeeper.properties
    for NODE_i in $NODE_LIST; do
      echo "Initializing server.properties for node: ${NODE_i}"
      
      # Defining each broker's server.properties
      PROPERTY_FILE_i="${KAFKA_CONF_DIR}/server-${NODE_i}.properties"
      
      # Copying default configuration
      cp "${KAFKA_CONF_DIR}/server.properties" "${PROPERTY_FILE_i}"
      
      # Modifying values
      sed -i 's!^\(broker.id=\).*!\1'$BROKER_ID_i'!g' "${PROPERTY_FILE_i}"
      sed -i 's!^\(listeners=PLAINTEXT://\).*$!\1'${NODE_i}':'${BROKER_PORT_i}'!g' "${PROPERTY_FILE_i}"
      sed -i 's!^\(log.dirs=.*\)$!\1_'${NODE_i}'!g' "${PROPERTY_FILE_i}"
      sed -i 's!^.*\(zookeeper.connect=\).*$!\1'${ZK_NODE}':2181!g' "${PROPERTY_FILE_i}"
      echo "port=${BROKER_PORT_i}" >> "${PROPERTY_FILE_i}"
      echo "broker_hostname=${NODE_i}" >> "${PROPERTY_FILE_i}"
      
      # Incrementing broker-id for more than one brokers
      ((BROKER_ID_i++))
      ##((BROKER_PORT_i++))
       
      # Start kafka server
      if [[ "$PROCESS" =~ ^(KAFKA|ALL)$ ]]; then
        srun_process_cmd "$NODE_i" "ml Java; nohup $KAFKA_HOME/bin/kafka-server-start.sh ${PROPERTY_FILE_i}"
      fi  
    done
  fi
fi


if [[ "$MODE" == "STOP"* ]]; then
  if [[ "$PROCESS" =~ ^(KAFKA|ALL)$ ]]; then
    for NODE_i in $NODE_LIST; do
      
      # Defining each broker's server.properties
      PROPERTY_FILE_i="${KAFKA_CONF_DIR}/server-${NODE_i}.properties"
      
      # Stop kafka server
      srun_process_cmd "${NODE_i}" "ml Java; ${KAFKA_HOME}/bin/kafka-server-stop.sh ${PROPERTY_FILE_i}"
    done
  fi
  if [[ "$PROCESS" =~ ^(ZOOKEEPER|ALL)$ ]]; then
    srun_process_cmd "${ZK_NODE}" "ml Java; ${KAFKA_HOME}/bin/zookeeper-server-stop.sh ${KAFKA_HOME}/config/zookeeper.properties"
  fi
fi

# End
