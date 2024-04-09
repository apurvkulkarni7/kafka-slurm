# Running Kafka Cluster on Slurm

# About
This contains script to run kafka cluster on Slurm based HPC/data centers


# Usage

- Set the `KAFKA_HOME` to your kafka directory on line 3 in [kafka_slurm.sh](./kafka_slurm.sh) 

- To start Zookeeper and Kafka cluster
```bash
./kafka_slurm.sh START_CLUSTER
```

- To stop Zookeeper and Kafka cluster
```bash
./kafka_slurm.sh STOP_CLUSTER
```

- To start/stop Zookeeper and Kafka broker on specific node
```bash
# For zookeeper
./kafka_slurm.sh START ZOOKEEPER <NODE_HOSTNAME>
./kafka_slurm.sh STOP ZOOKEEPER <NODE_HOSTNAME>

# For kafka
./kafka_slurm.sh START KAFKA <NODE_HOSTNAME>
./kafka_slurm.sh STOP KAFKA <NODE_HOSTNAME>
```

# License
GNU GENERAL PUBLIC LICENSE Version 3