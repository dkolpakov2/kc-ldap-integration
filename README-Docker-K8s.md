
✅ To speed up Docker container startup in EKS using caching
- EKS provides pre-built Amazon EKS optimized Amazon Machine Images (AMIs) for:
     1. Amazon Linux and 
     2. Bottlerocket.
- leverage Docker's build cache, pre-pull images, and potentially use a local registry mirror like Spegel. 
- Docker buildx build with --cache-from and --cache-to can utilize existing image layers, while pre-pulling images on nodes using daemonsets or service OS can minimize pull times during pod scheduling.

1. Docker Build Cache:
Dockerfile Optimization:
.
Arrange your Dockerfile instructions to maximize cache hits. Frequently changing instructions (e.g., COPY with frequently changing source files) should be placed towards the end of the file. 
docker buildx build with --cache-from and --cache-to:
.
Use docker buildx build --cache-from type=registry,ref=<image_name> --cache-to type=registry,ref=<image_name> . to utilize a remote cache during builds. 
Cache Storage:
.
Choose a suitable cache storage backend like a registry or a persistent volume (PVC). 

2. Image Pre-pulling: Prefetch the container image contents locally to eliminate the need of image downloading;
    Daemonsets:
Deploy daemonsets to pre-pull frequently used images on all nodes in the EKS cluster, ensuring images are available locally when pods are scheduled. 
service OS:
Consider using service for its optimized container runtime and potential for faster image loading. 
Spegel: 
Utilize Spegel, a cluster-local registry mirror, to enable nodes to share image layers between themselves, reducing pull times and egress traffic. 

3. Other Considerations:
Lightweight Base Images: Use smaller base images to reduce image size and pull times. 
Image Size: Minimize the overall size of your container images. 
Kubernetes Image Pull Policy: Ensure the correct imagePullPolicy is set for your pods (e.g., IfNotPresent or Never if images are    already pre-pulled). 
Client-Side Cache: If using kubectl frequently, ensure it has a local cache enabled to reduce API calls to the Kubernetes API server. 
=============
How do we prefetch container images:
In this solution, we take an Amazon Elastic Block Store (Amazon EBS) snapshot of the service data volume, and reuse this snapshot in an Amazon EKS node group so that all necessary images are already prefetched in local disk once the worker node starts.

    The previous processes are automated via a script and details in the following details:
1. Spin up an Amazon Elastic Compute Cloud (Amazon EC2) instance with Amazon EKS optimized service AMI;
2. Pull application images from the image repository;
3. Take a Amazon EBS snapshot of the service data volume;
4. Create an Amazon EKS node groups and map the snapshot to its data volume.
>> Architecture
DockerHUB ->ECR -> MultiArch Container Images-> EC2 (OS Volume, Data Volume) -> 2.
                                        2. -> service Volume Snapshot-> EBS-> EKS Worker Node with  service
================
Trace Events inside the Kubernetes POD:
>> NO_PREFETCH_POD=$(kubectl get pod -l app=inflate-no-prefetch -o jsonpath="{.items[0].metadata.name}")
>> kubectl get events -o custom-columns=Time:.lastTimestamp,From:.source.component,Type:.type,Reason:.reason,Message:.message  --field-selector involvedObject.name=$NO_PREFETCH_POD,involvedObject.kind=Pod
================
5. Results
By using service to prefetch the large container image, we were able to reduce the time it takes to start a pod from 49 seconds to just 3 seconds.
================================================
Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

Here is a simple example where an Ingress sends all its traffic to one Service:
ingress-diagram
    User->LBalancer Ingress Managed -> Ingress ->Routing Rule-> Service -> Pod
    
🔧 Bonus: Ingress (Not a Service type)
 1. Ingress is not a Service, but a separate API object
 2. It acts like a reverse proxy with routing, TLS, and virtual hosts
 3. Backed by ClusterIP services and fronted by a LoadBalancer service

# DOCKER COMPOSE to get interactive prompt:
>> docker-compose exec web sh
>> docker-compose up --build
>> docker-compose down   <- remove old containers Stop and clean up
docker-compose up -d         # Start API and dependencies
# for local get into container interactive prompt:
>> winpty docker exec -it Reporter sh
>> winpty docker exec -ti -u root container_name bash    ## as root user
>> ps -ef | grep OSS 
#####################
docker build --no-cache -f Dockerfile -t name:pgclient .
docker build -t my-api-image .
docker tag 
docker push
>> winpty docker exec -it keycloak_1 sh
winpty docker exec -it keycloak sh
docker run -d --rm --name keycloak -p 443:8443 -e KEYSTORE_PASSWORD=secret -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=password -v $(pwd):/etc/x509/https keycloaklocal:4.8.0

# Run 
docker run -d -p 8080:8080 --name my-api-container my-api-image
    -d: Detached mode (runs in background)
    -p: Maps host port to container port (API runs on localhost:8080)
    --name: Assigns a name to the container
docker ps    = View Running containers    
docker stop my-api-container
docker restart my-api-container
docker logs -f my-api-container  ## => -f: Follow log output in real time (like tail -f)
docker images    => list images
docker system prune -a  # => clean up unused resources

## Test:
curl -H "Authorization: Bearer <your-jwt-token>" http://localhost:8080/api/secure-endpoint
## Access into docker:
docker exec -it my-api-container /bin/bash 

docker run -d --rm --name nginx -p 443:8443 nginx:nginx
## Push Docker image to DEV AWS ECR
# docker build -f Dockerfile -t renewables-dna-ds-ecr:iac-svc .
# aws --profile newdev ecr get-login-password --region us-east-1 --no-verify-ssl | docker login --username AWS --password-stdin .dkr.ecr.us-east-1.amazonaws.com
# docker tag renewables-dna-ds-ecr:iac-svc .dkr.ecr.us-east-1.amazonaws.com/renewables-dna-ds-ecr:ren-iac-svc
# docker push .dkr.ecr.us-east-1.amazonaws.com/renewables-uai3031357-dna-ds-ecr:ren-iac-svc
>>
#
docker run -d --name postgres --net keycloak-network -e POSTGRES_DB=keycloak -e POSTGRES_USER=keycloak -e POSTGRES_PASSWORD=password postgres
docker run -d -link postgres:db user/wordpress
docker run -d --net mynet --name container1 my_image
docker container stop keycloak
docker container rm keycloak
# run netstat on container:
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' container_name_or_id) -n netstat
netstat -na | grep :8443
docker inspect -f '{{.State.Pid}}' value-mapper
nsenter -t <pid> -n netstat -na | grep :8443
docker exec -it -u root value-mapper /bin/bash
netstat -tapn | grep 5432
$ netstat -an | more
ifconfig: Displays the configuration for a network interface
traceroute: Shows the path taken to reach a host
>>> KUBECT
## Create Secret:
kubectl create secret generic svc-secret \
--from-literal=username='name' \
--from-literal=password='pass'
aws-iam-authenticator version
aws sts get-caller-identity
# aws configure   -- is to configur
 aws --profile prod ec2 describe-instances --region us-east-1
kubectl -n ds get hpa | grep notes
kubectl describe hpa nt-svc
kubectl scale deployments jmeter-agent --replicas=9 -n jmeter
winpty kubectl exec -it  svc -n ds -c svc-2 -- bash
kubectl get pods --all-namespaces -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' | sort
# how to update a Secret on ConfigMap
>> kubectl create secret generic my-secret --from-literal=foo=bar --dry-run -o yaml | kubectl apply -f deployment.yaml
>> kubectl create configmap my-config --from-literal=foo=bar --dry-run -o yaml | kubectl apply -f -
# CPU Usage:
>> kubectl top pod jmeter-agent -n jmeter
kubectl delete pod jmeter-master   --grace-period=0 --force --namespace jmeter
kubectl autoscale deployment jenkins --cpu-percent=75 --min=1 --max=10 -n dev
kubectl create -f devops/autoscaling.yaml -n dev
To check the node public IP address, run the following command:
    kubectl get nodes -n ds -o wide |  awk {'print $1" " $2 " " $7'} | column -t
To verify that your pods are running and have their own internal IP addresses, run the following command:
    kubectl get pods -n ds -l 'app=name' -o wide | awk {'print $1" " $3 " " $6'} | column -t
To get information about service, run the following command:
    kubectl get service/names |  awk {'print $1" " $2 " " $4 " " $5'} | column -t   
To verify that you can access the load balancer externally, run the following command:
    curl -silent <external-ip-from-prev-commnd->.eu-west-1.elb.amazonaws.com:8080 | grep title
kubectl port-forward deployment/deploymentName 8089
kubectl port-forward $(kubectl get pod -l "app=name" -o jsonpath={.items[0].metadata.name}) 31000
#EXPOSE Service for deployment
kubectl expose deployment name -n dev --port 8080 --target-port 8080 --type=LoadBalancer
#Expose external-IP:
kubectl patch svc name -n dev -p '{"spec": {"type": "LoadBalancer", "externalIPs":["100.10.10.10"]}}'
kubectl create -f deployment-service.yaml -n ds --save-config
kubectl top nodes
kubectl cluster-info dump
kubectl describe secrets svc-secret -n default
------------------------------------MINIKUBE-----------------------------------
choco install minikube -y
# Minikube:
..\Documents\chocolatey\tools\chocolateyInstall\bin
>minikube start
minikube start --vm-driver=hyperv
minikube delete
minikube start --vm-driver=hyperv --v=7 --alsologtostderr
kubectl get nodes
minikube ip
minikube docker-env.
@FOR /f "tokens=*" %i IN ('minikube docker-env') DO @%i

Depoy smashing to kubernetes
kubectl run smashing --image=visibilityspots/smashing --port=3030 --restart=Never
kubectl get pods
kubectl expose pods smashing --type=NodePort
#open service in local browsing
minikube service smashing
minikube dashboard
Easiest way to create JKS store: run CMD as admin: 
1. >> openssl pkcs12 -export -in cert_com.crt -inkey cert.pem -out keystore.p12
- Install keytool
2. >> keytool -importkeystore -srckeystore keystore.p12 -srcstoretype PKCS12 -destkeystore keycloak.jks -deststoretype JKS
openssl s_client -host 127.0.0.1 -port 443 -debug -prexit -bugs -showcerts
openssl ciphers -s -v
openssl ciphers -v | awk '{print $2}' | sort | uniq 
curl -v --ciphers DHE-RSA-AES128-GCM-SHA256 https://example.com , 
openssl s_client -connect example.com:443 , 
openssl s_client -connect example.com:443 -mtu 1478 -msg -cipher DHE-RSA-AES128-GCM-SHA256, 
curl --http2 --cacert cert.crt --key ca.key --location --request POST 'https://domainname.com
curl -s -H 'Host: domainname.com' -H 'X-Forwarded-For: 10.242.198.171' -H 'X-Forwarded-Proto: https'POST
curl -iv -k --ciphers ALL -HHost:domainname.com --request GET 'https://127.0.0.1:443/auth/realms/master/protocol/openid-connect/certs' --verbose
------
curl -iv -k --ciphers ALL --tls-max 1.2 --location --request GET 'https://domainname.ge.com/auth/realms/RENDS/protocol/openid-connect/certs' --verbose
- context:
    cluster: test
    user: test
  name: test
current-context: dev
kind: Config
preferences: {}
- name: dev
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - token
      - -i
      - dev-cluster
      - -r
      - arn:aws:iam::role/aws-developer
      command: aws-iam-authenticator
      env:
      - name: AWS_PROFILE
        value: dev
      interactiveMode: IfAvailable
>> RUN multi user load
#!/usr/bin/env bash

# usage
# ./start-jmeter-test.sh scripts/TaskNotes2.jmx instance1
# ./start-jmeter-test.sh scripts/TaskNotes2.jmx instance2

LOCKFILE='lock.pid'
# check for existing lockfile
	if [ -e "$LOCKFILE" ]; then
# lockfile exists - ensure that it's readable
		[ -r "$LOCKFILE" ] || { echo error: lockfile is not readable; exit 1; }
# ensure that process that created lockfile is no longer running
		kill -0 "`cat "$LOCKFILE"`" 2>/dev/null && { echo error: an instance of this script is already running; exit 1; }
# delete lockfile
		rm -f "$LOCKFILE" || { echo error: failed to delete lockfile; exit 1; }
	fi

# create lockfile
	echo $$ >"$LOCKFILE" || { echo error: failed to create lockfile; exit 1; }

#
JMETER_HOME="/jmeter/apache-jmeter-5.0"
working_dir="`pwd`"
echo "work_dir:" $working_dir
#Get namesapce variable
tenant=`awk '{print $NF}' "$working_dir/pft_export"`
echo "tenant -> " $tenant

# TODO add param to shell
jmx="$1"
[ -n "$jmx" ] || read -p 'Enter path to the jmx file ' jmx
if [ ! -f "$jmx" ];
then
    echo "Test script file was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi
test_name="$(basename "$jmx")"
#Get Master pod details
#jmx=$(echo $1 | cut -d' ' -f 1)
#pods=$(echo $1 | cut -d' ' -f 2)
username=$(echo $2 | cut -d' ' -f 2)
echo "username= "$username
#username=$(kubectl get pods -o=jsonpath='{range .items..metadata}{.name}{"\n"}{end}' | fgrep {print $username})

# save test start time
DATE=`date`
echo $test_name = "test_started->'$DATE'" > $working_dir/test_$username
aws s3 cp $working_dir/test_$username s3://renewables-uai3031357-config-qa/testpft/test_$username --sse-kms-key-id arn:aws:kms:us-east-1:487459321624:key/435837b1-af36-4eab-b10c-31279d4de750 --sse aws:kms --acl bucket-owner-full-control  --no-verify-ssl 
#

master_pod=`kubectl get pod -n pft | grep 'jmeter-server-'$username | awk '{print $1}'`

echo "server master pod ->" $master_pod

#kubectl cp $jmx -n $tenant $master_pod":/QA-test-plan-1UserBased-5-10.jmx"
kubectl cp $jmx -n $tenant $master_pod":/""$test_name"


echo "jmx file copied!"
echo "test name to run-> " "'$test_name'"
# copy load_test.sh
kubectl cp load_test.sh -n $tenant $master_pod":/load_test.sh"
winpty kubectl exec -it -n $tenant $master_pod -- bash -c 'chmod 755 /load_test.sh'
echo "load_test file copied!"

## Echo Starting Jmeter load test
deploymentName="jmeter-agent-$username"
agentPodName=$(kubectl get pods -n pft -o=jsonpath='{.items[*].metadata.name}{"\n" " "}' | grep -oP "${deploymentName}.*?\s")

echo "agentPods -> $agentPodName"
# kubectl logs ${agentPodName} -n pft 

# kubectl get pods -n pft -l app=jmeter-agent-svc-dmitry -o=jsonpath="{range .items[*]}{.status.podIP}{','}{end}"

## Echo Starting Jmeter load test
# new 
pod=$(kubectl get pods -n pft -l jmeter_mode=agent-$username -o=jsonpath="{range .items[*]}{.status.podIP}{','}{end}")
pods=$(echo ${pod% *})
echo "$pods"
pod=${pods//[ ]/:1099,}
pods=$(echo ${pod%,*})
echo "PODS-> ""$pods"

# get Server pod
serverName="jmeter-server-$username"
serverPod=$(kubectl get pods -n pft -o=jsonpath='{.items[*].metadata.name}{"\n" " "}' | grep -oP "${serverName}.*?\s")
echo "serverPod -> $serverPod"

# add below line if fails to run on remote server wit ERROR->>  bash: ./load_test.sh: /bin/bash^M: bad interpreter: No such file or directory command terminated with exit code 126
#sed -i -e 's/\r$//' load_test.sh

# new
winpty kubectl exec -it -n $tenant $serverPod -- bash -c './load_test.sh '"'$test_name $pods'" 

# Copy logs:
JMETER_HOME="/jmeter.log"
JMETER_LOG_RESULTS="/testresults.jtl"
echo 'Copy Server - Master log has been started...'
kubectl -n $tenant cp $master_pod:$JMETER_HOME results$JMETER_HOME
kubectl -n $tenant cp $master_pod:$JMETER_LOG_RESULTS results$JMETER_LOG_RESULTS

echo 'clear - Master Server log is started...'
winpty kubectl -n $tenant exec -it $master_pod -- bash  -c 'rm /testresults.jtl'
echo 'clear summary of master logs is done!'

#  kubectl -n pft cp jmeter-server:/testresults.jtl results/endure-157000-1pod.jlt
echo 'Server logs have been copied!'
# Copy agent logs
client_IP=$( kubectl get pods -n pft -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}')
echo 'Copy agent logs has been started...'
echo 'client-ips-> ' $client_IP
JMETER_LOG="/jmeter-server.log"

for ip in $(echo $client_IP | sed "s/,/ /g")
    do
    if [[ "$ip" == *"agent-$username"* ]]; then
        echo "coping from ip-> " "$ip"
        kubectl -n $tenant cp $ip:$JMETER_LOG results/$ip$JMETER_LOG
    fi
done
echo 'Download of agent logs has been competed!'

# Save test done timestamp 
DATE=`date`
echo $test_name = "test_done->'$DATE'" > $working_dir/test_$username

aws s3 cp $working_dir/test_$username s3://s3name/testpft/test_$username --sse-kms-key-id arn:aws:kms:us-east-1:kms-key --sse aws:kms --acl bucket-owner-full-control  --no-verify-ssl 
>>>

      provideClusterInfo: false
RUNNING
# with replica
mongod --port 27017 --dbpath /srv/mongodb/db0 --replSet rs0 --bind_ip localhost,<hostname(s)|ip address(es)>
mongod --port 27017 --replSet rs0 --bind_ip localhost
mongod --port 27017  --bind_ip localhost

>>> aws
aws s3 ls s3://s3bucketname/ --no-verify-ssl
aws s3 cp test1.txt s3://s3name/681.txt --sse-kms-key-id arn:aws:kms:us-east-1:kms-key --sse aws:kms --acl bucket-owner-full-control  --no-verify-ssl
aws iam list-roles
>>$ aws events put rule --name daily_task --schedule-expression 'cron(0 5 ? * MON-FRI *)'
>>$ aws events list-rules


