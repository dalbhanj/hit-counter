# ReadMe

A basic Python web app to demonstrate Amazon ECS capabilities

### Pre-requisites
1. Make sure you have [docker-compose](https://docs.docker.com/compose/install/), [docker](https://docs.docker.com/engine/installation/), [aws cli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) installed on your machine
Note: docker is preinstalled if you choose Amazon ECS instance for development

2. The Instance role has AmazonEC2ContainerRegistryPowerUser[http://docs.aws.amazon.com/AmazonECR/latest/userguide/ecr_managed_policies.html] policy attached

### Get started in <2 mins

1. Clone this repository
    ```
    $ git clone https://github.com/dalbhanj/hit-counter
    ```
2. Use docker-compose to start the application
    ```
    $ docker-compose up
    ```
The web app should now be listening on port 80 on the host IP address (make sure security group has port 80 open)

Read on to complete the demo of Amazon ECS and its capabilities 

### Deploy on Amazon ECS

Now that our app working, let's run it as a task in ECS

Actually before we run it as a task, we will make one more change to the application. We will remove Redis container from our configuration and use Elasticache Redis cluster as a central server to keep the count of visitors. By doing this, we will get scaling flexibility for our application

1. Create [Elasticache Redis server](http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/AmazonVPC.html) in the VPC and give access to security group used by ECS container instance. Copy Redis node endpoint, edit app.py and replace host configuration  
    ```
    redis = Redis(host='DNS_NODE_ENDPOINT', port=6379)
    ```

2. Rebuild your app
    ```
    $ docker-compose build
    $ docker-compose up
    ```
3. Stop the app
    ```
    $ docker-compose down
    ```

4. Create an ECR repo (hitcounter)

5. Authenticate, Tag and Push Docker image (hitcounter_web) to ECR. You will find relevant commands when you click 'View Push Commands' from repository page
    ```
    $ aws ecr get-login --region us-east-1
    $ docker tag hitcounter_web:latest xxxxxx.us-east-1.amazonaws.com/hitcounter:latest
    $ docker push xxxxxx.us-east-1.amazonaws.com/hitcounter:latest
    ```

6. Register hitcounter-taskdef into ECS
    ```
    $ aws ecs register-task-definition --family hit-counter --cli-input-json file://hitcounter-wo-redis.json 
    ```
7. Scale Container Instances by clicking "Scale ECS Instances" and set Desired number of instances to 4 hosts

8. Choose the task definition and [Create a Service with an ALB](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-service.html) using ECS console (make sure to choose container port 5000 while defining ALB Target Groups. If your service is running fine but ALB Target status is unhealthy, make sure ALL TCP ports are open to ALB Security Group on Container Instance Security Group)

This exercise demonstrates quicker way of taking an application under development to a highly available service running on ECS 

To learn more about Amazon ECS, please visit https://aws.amazon.com/ecs/

## Cleanup
Go to Tasks tab and Stop all tasks first. Delete ECS Cluster, this will delete Container instances and resources created by CloudFormation template. Finally, delete ELB and its Target Groups



