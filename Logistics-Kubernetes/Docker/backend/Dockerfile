# Use an official OpenJDK runtime image
FROM openjdk:21-jdk-slim

# Set a working directory
WORKDIR /app

# Copy the JAR file to the working directory
COPY ./target/Logistics-0.0.1-SNAPSHOT.jar /app/Logistics.jar

# Expose the application port (adjust if your app uses a different port)
EXPOSE 8080

# Run the application (in the foreground, logs will be visible with `docker logs`)
CMD ["java", "-jar", "/app/Logistics.jar"]
