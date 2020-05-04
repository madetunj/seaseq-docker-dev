# seaseq-docker-dev

##Getting started
1. Building the image

    ```bash
    git clone https://github.com/madetunj/seaseq-docker-dev.git
    cd seaseq-docker-dev
    docker build -t seaseq .
        
    ###run example file
    git clone https://github.com/madetunj/seaseq-dev.git
    
    mkdir results
    docker run \
    --mount type=bind,source=$(pwd)/seaseq-dev/test,target=/data,readonly \
    --mount type=bind,source=$(pwd)/results,target=/results \
    seaseq \
    /data/test/inputyml.yml
    ```
    
1. Pulling from Docker repo

    ```bash
    docker pull madetunj/seaseq:v1.0.0
    
    ###run example file
    git clone https://github.com/madetunj/seaseq-dev.git
    
    mkdir results
    docker run \
    --mount type=bind,source=$(pwd)/seaseq-dev/test,target=/data,readonly \
    --mount type=bind,source=$(pwd)/results,target=/results \
    madetunj/seaseq:v1.0.0 \
    /data/test/inputyml.yml
    ```