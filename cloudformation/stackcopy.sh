#!/bin/bash 
echo Enter Date in from yyyy-dd-mm
read date 
echo $date 



aws s3 cp   s3://hubs-cloud/stack-beta.yaml   "s3://hubs-cloud/release/$date/stack-beta.yaml"


aws s3 cp   s3://hubs-cloud/stack-personal.yaml   "s3://hubs-cloud/release/$date/stack-personal.yaml "

aws s3 cp   s3://hubs-cloud/stack-pro.yaml   "s3://hubs-cloud/release/$date/stack-pro.yaml"

aws s3 cp   s3://hubs-cloud/stack-pro-single.yaml   "s3://hubs-cloud/release/$date/stack-pro-single.yaml "

