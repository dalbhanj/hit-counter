== ReadMe
:toc:
:icons:
:linkattrs:

Simple demo to demonstrate migration of locally developed application into Amazon ECS and then to Fargate

=== Pre-requisites
Make sure you have https://docs.docker.com/compose/install/[docker-compose], https://docs.docker.com/engine/installation/[docker], http://docs.aws.amazon.com/cli/latest/userguide/installing.html[awscli] installed on your machine

=== Download the app and run it on local PC

1. Clone this repository

    $ git clone https://github.com/dalbhanj/hit-counter

2. Use docker-compose to start the application

    $ docker-compose up

The web app should now be listening on port 80 on the host IP address

Bring the application down using CTRL+C or ```docker-compose down```

Now that our app works, let's run this on ECS

=== Deploy on Amazon ECS

Actually before we run it as a task, we will make one more change to the application.
We will remove Redis container from our configuration and use
https://aws.amazon.com/elasticache/redis/[Elasticache Redis cluster] as a centralized
data store to keep the count of visitors. By doing this, we can achieve HA and use built-in
 features of managed Redis service while we focus on our app development

1. Let's create a http://docs.aws.amazon.com/AmazonECS/latest/developerguide/create_cluster.html[ECS cluster]
with EC2 hosts using https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_tutorial_EC2.html[ECS CLI].

    $ export ECS_PROFILE=hitcounter_ec2
    $ ecs-cli configure --cluster hitcounter-ec2 --region us-east-1 --default-launch-type EC2 --config-name hitcounter-ec2
    $ ecs-cli configure profile --access-key $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_ACCESS_KEY --profile-name hitcounter-ec2
    $ ecs-cli configure default --config-name hitcounter-ec2
    $ ecs-cli up --keypair id_rsa --capability-iam --size 2 --instance-type t2.medium

2. Create a https://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/GettingStarted.CreateCluster.html[standalone Elasticache Redis instance]
in the same VPC and give access to security group used by ECS container instance.

3. Once Redis is ready, copy the node endpoint and replace host configuration within app.py (don't
add :6379)

    redis = Redis(host='DNS_NODE_ENDPOINT', port=6379)

4. Configure https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html[Security Groups] created by
ecs cli tool and open port 80 to internet and 6379 to its own SG

5. Rebuild your app

    $ docker-compose build

6. Before you can deploy this app on ECS, you need to push hitcounter_web image to ECR repo.
Create an ECR repo (hitcounter)

    $ aws ecr create-repository --repository-name hitcounter

7. Authenticate, Tag and Push Docker image (hitcounter_web) to ECR.

    $ aws ecr get-login --no-include-email --region us-east-1 | sh
    $ docker tag hitcounter_web:latest aws_account_id.dkr.ecr.us-east-1.amazonaws.com/hitcounter:latest
    $ docker push aws_account_id.dkr.ecr.us-east-1.amazonaws.com/hitcounter:latest

8. Comment out redis build, replace web with ECR repository URI and add logging info into docker-compose file (this is
 saved as hitcounter-service.yml)

    version: '2'
    services:
      web:
        image: aws_account_id.dkr.ecr.us-east-1.amazonaws.com/hitcounter:latest
        # build: .
        command: gunicorn app:app -b 0.0.0.0:80
        # depends_on:
        #   - redis
        ports:
          - "80:80"
        logging:
          driver: "awslogs"
          options:
            awslogs-region: "us-east-1"
            awslogs-group: "ecs/hitcounter"
            awslogs-stream-prefix: "hitcounter"
      # redis:
      #   image: redis

9. Deploy the app on ECS

    $ ecs-cli compose --file hitcounter-service.yml up --create-log-groups

10. Now that our app is working on ECS, we will run this as a Service and use ALB for load balancing.
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-application-load-balancer.html[Create an ALB]
first and then use ecs-cli to create a Service

    $ ecs-cli compose --project-name hitcounter --file hitcounter-service.yml service up --target-group-arn <arn> --container-name web --container-port 80 --role ecsServiceRole

11. Let's Scale our application

    $ ecs-cli compose --project-name hitcounter --file hitcounter-service.yml service scale 2

12. You can run load generator app against your app to increase the number of  Container
Instances. For now let's scale manually by setting desired count to 4 hosts

    $ aws autoscaling update-auto-scaling-group --auto-scaling-group-name <value> --launch-configuration-name <value> --min-size 0 --max-size 4
    $ aws autoscaling set-desired-capacity --auto-scaling-group-name <value> --desired-capacity 4

13. https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-autoscaling-targettracking.html[Configure Service Autoscaling]
by setting desired scaling policies for your service

14. Run Apache benchmark utility to test service autoscaling functionality.

    $ ab -n 100000 -c 1000 <elb-dns-name>

=== Deploy on Fargate

Great to see our app running as highly available service on ECS. Now let's get rid of the infrastructure and
run this as a Fargate service.

1. Create Fargate infrastructure similar to Step 1 above (use https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_tutorial_fargate.html[tutorial]
for reference)

    $ export ECS_PROFILE=hitcounter_farg8
    $ ecs-cli configure --cluster hitcounter-farg8 --region us-east-1 --default-launch-type FARGATE --config-name hitcounter-farg8
    $ ecs-cli configure profile --access-key $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_ACCESS_KEY --profile-name hitcounter-farg8
    $ ecs-cli configure default --config-name hitcounter-farg8
    $ ecs-cli up --keypair id_rsa --capability-iam --size 2 --instance-type t2.medium

2. Let's create a Fargate service using hitcounter-farg8-service.yml and ecs-parameters.yml

    $ ecs-cli compose --project-name hitcounter --file hitcounter-farg8-service.yml --ecs-params ecs-parameters.yml service up --create-log-groups

3. Let's make it HA service by attaching to the Load Balancer and configure scaling

    $ ecs-cli compose --project-name hitcounter --file hitcounter-farg8-service.yml --ecs-params ecs-parameters.yml service up --create-log-groups --target-group-arn <arn> --container-name web --container-port 80
    $ ecs-cli compose --project-name hitcounter --file hitcounter-farg8-service.yml --ecs-params ecs-parameters.yml service scale 2

== Conclusion
This exercise demonstrates how to migrate an app that was developed on your local PC to a
highly available service on ECS and then moving to Fargate.

To learn more about Amazon ECS, please visit https://aws.amazon.com/ecs/

== Cleanup

1. Here are cleanup steps for EC2 tasks. First scale the number of desired tasks to 0 and then delete the Service

    $ ecs-cli compose --project-name hitcounter --file hitcounter-service.yml service scale 0
    $ ecs-cli compose --project-name hitcounter --file hitcounter-service.yml service rm

2. Cleanup steps for Fargate tasks.

    $ ecs-cli compose --project-name hitcounter --file hitcounter-farg8-service.yml service scale 0
    $ ecs-cli compose --project-name hitcounter --file hitcounter-farg8-service.yml service scale rm

3. Delete Elasticache Redis Cluster

4. Delete ELB and Target Groups

5. Delete both ec2 and fargate clusters

    $ ecs-cli down --force

== Troubleshooting

If you get an error on Step 2, make sure you have Docker for https://www.docker.com/docker-mac[Mac] or https://www.docker.com/docker-windows[Windows] installed and started on your PC

  $ docker-compose up
  ERROR: Couldn't connect to Docker daemon. You might need to start Docker for Mac.
