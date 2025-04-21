FROM alpine/java:21-jre
RUN apk update && apk upgrade libexpat
WORKDIR /home/app/

# Copy all .jar files to the working directory
COPY ./target/*.jar /home/app/

# Use a shell to dynamically find the .jar file and run it
CMD sh -c 'java -jar /home/app/$(ls /home/app/ | grep .jar)'