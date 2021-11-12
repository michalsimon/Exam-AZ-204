cd ./dockerwebapp

#Step 1 - build the container defined in the Dockerfile
docker build -t dockerwebapp:v1 .

#Step 2 - check if image exist
docker image ls dockerwebapp:v1

#Step 3 - run the container locally 
docker run --name dockerwebapp --publish 8080:80 --detach dockerwebapp:v1
curl http://localhost:8080

#Step 4 - delete the running container
docker stop dockerwebapp
docker rm dockerwebapp