#!/bin/bash

docker_host_setup(){

  ##SET UP THE REPOSITORY
  sudo apt-get update 
  sudo apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

## Installing docker package on docker host
  sudo apt-get update
  sudo apt-get install docker-ce -y

## Add Docker daemon configuration
  cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "icc": false,
  "disable-legacy-registry": true,
  "userland-proxy": false,
  "live-restore": true
}
EOF

  # Post docker installation steps
  # Start docker service
  sudo systemctl enable docker
  sudo systemctl start docker
  # Add current user to docker group
  sudo usermod -aG docker $USER
  # verify docker is working
  docker version
  docker info

  # Installing docker-compose package on docker host
  sudo apt-get update
  sudo apt-get install docker-compose -y
  
  # verify docker-compose is working
  docker-compose version
}

docker_container_build() {
    
    # Download the config files for the docker container
    # Download docker-compose.yml for run the service
    curl -fsSL https://sourceforge.net/p/evotutoring/code/HEAD/tree/branches/EvoParsons-Epplets/docker/docker-compose.yml?format=raw -o docker-compose.yml
    # Download the Dockerfile and supervisord.conf for build the Docker image
    curl -fsSL https://sourceforge.net/p/evotutoring/code/HEAD/tree/branches/EvoParsons-Epplets/docker/Dockerfile?format=raw -o Dockerfile
    curl -fsSL https://sourceforge.net/p/evotutoring/code/HEAD/tree/branches/EvoParsons-Epplets/docker/supervisord.conf?format=raw -o supervisord.conf

   if [ "$#" -ne  2 ]; then
    echo "Usage:"
    echo "    $0 build <port> <Hostname>"
    echo "Example: $0 build 1235 spell.forest.usf.edu "
    return 1
  fi

  local port=${1}
  local BROKER_HOSTNAME=${2}
  echo "Port: $port"
  echo "BROKER_HOSTNAME: $BROKER_HOSTNAME"
  sed -i 's/99999/'"$port"''/'g' Dockerfile
  sed -i 's/TESTNAME/'"$BROKER_HOSTNAME"''/'g' Dockerfile
 
  docker build -t evoparsons_server$port -f Dockerfile .

  sed -i 's/image: .*/image: evoparsons_server'"$port"''/'g' docker-compose.yml
}


docker_container_run() {

  if [ "$#" -ne  4 ]; then
    echo "Usage:"
    echo "    $0 up <name> <port> <BROKER_HOSTNAME> <data_directory>"
    echo "    Example: $0 up class1 1111 localHost ./class1"
    echo ""
    return 1
  fi

  local name=${1}
  local port=${2}
  local BROKER_HOSTNAME=${3}
  local data=${4}
  
  echo "Starting services for $name ..."
  echo "Port: $port"
  echo "BROKER_HOSTNAME: $BROKER_HOSTNAME"
  echo "Data folder: $data"

  export BROKER_PORT=$port
  export BROKER_HOSTNAME=$BROKER_HOSTNAME
  export DATA_DIR=$data

  docker-compose -p $name up -d
}



docker_container_down() {

  if [ "$#" -ne  1 ]; then
    echo "Usage:"
    echo "    $0 down <name>"
    return 1
  fi
  p=_EvoParsonsServer_1
  local name=${1}
  echo "Shutting down ..."
  docker stop $name$p
}

docker_container_logs(){

  if [ "$#" -ne  1 ]; then
    echo "Usage:"
    echo "    $0 logs <name>"
    return 1
  fi
  p=_EvoParsonsServer_1
  local name=${1}
  shift
  echo "Logs for $name$p..."
  docker logs $name$p
}


# script starts here
command=$1
shift

case "$command" in
    build) docker_container_build $@ ;;
    up) docker_container_run $@ ;;
    down) docker_container_down $@ ;;
    logs) docker_container_logs $@ ;;
    host_setup) docker_host_setup $@ ;;
    *)        echo "Usage: <build|up|down|logs|host_setup>" ;;
esac
