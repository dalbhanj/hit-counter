# hit_counter

A basic Python web app to demonstrate linking docker containers

## Pre-requisites
1) Make sure you have docker-compose[https://docs.docker.com/compose/install/], docker[https://docs.docker.com/engine/installation/], aws cli[http://docs.aws.amazon.com/cli/latest/userguide/installing.html] is installed 
Note: docker is preinstalled if you choose ECS instance for development

2) The Instance role has AmazonEC2ContainerRegistryPowerUser[http://docs.aws.amazon.com/AmazonECR/latest/userguide/ecr_managed_policies.html] policy attached

## Get started in <2 mins

Clone this repository

    $ git clone https://github.com/dalbhanj/hit_counter

Use docker-compose to start the application

    $ docker-compose up

That's it! The web app should now be listening on port 80 on the host IP address (make sure security group has port 80 open)

Read on if you want to demo ECS and its capabilities 

xxxxxxxxxxxxxxxxxxxx

Now that our app working, let's run it as a task in ECS

Actually before we run it as a task, we will make one more change to the application. We will remove Redis container from our configuration and use central redis server running on Elasticache Redis to keep an account of number of visitors. By doing this, we will get scaling flexibility for our application

Create Elasticache Redis server[http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/AmazonVPC.html] in the VPC used by ECS container instance and give access to same security group. Copy Redis node endpoint, edit app.py and replace host configuration  
    redis = Redis(host='DNS_NODE_ENDPOINT', port=6379)

Restart your app
    $ docker-compose build
    $ docker-compose up

Stop the app and push the image to ECR 
    $ docker-compose down

Create an ECR repo (hitcounter)

Authenticate, Tag and Push Docker image (hitcounter_web) to ECR. You will find relevant commands when you click 'View Push Commands' from repository page
    $ aws ecr get-login --region us-east-1
    $ docker tag hitcounter_web:latest xxxxxx.us-east-1.amazonaws.com/hitcounter:latest
    $ docker push xxxxxx.us-east-1.amazonaws.com/hitcounter:latest

Register hitcounter-taskdef into ECS
    $ aws ecs register-task-definition --family hit-counter --cli-input-json file://hitcounter-taskdef.json 






