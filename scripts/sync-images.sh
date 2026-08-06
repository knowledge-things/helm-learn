#!/bin/bash

set -e


IMAGE_FILE=$1

SWR_REGISTRY=${2:-swr.cn-north-4.myhuaweicloud.com}

SWR_NAMESPACE=${3:-dk-infra}


if [ -z "$IMAGE_FILE" ]; then

    echo "Usage:"
    echo "./sync-images.sh images.txt [registry] [namespace]"

    exit 1

fi


if ! command -v crane >/dev/null 2>&1
then
    echo "crane not installed"
    exit 1
fi


echo "Source images:"
cat $IMAGE_FILE

echo ""


while read -r IMAGE
do

    # 跳过空行
    [ -z "$IMAGE" ] && continue


    # 获取镜像名称
    NAME=$(echo $IMAGE \
        | awk -F/ '{print $NF}')


    TARGET="${SWR_REGISTRY}/${SWR_NAMESPACE}/${NAME}"


    echo "================================"
    echo "SOURCE:"
    echo "$IMAGE"

    echo "TARGET:"
    echo "$TARGET"


    crane copy \
        --platform linux/amd64 \
        "$IMAGE" \
        "$TARGET"


    echo "DONE"

done < "$IMAGE_FILE"


echo ""
echo "All images synced."