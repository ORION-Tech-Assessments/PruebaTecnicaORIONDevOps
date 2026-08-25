
ARG BUILD_IMAGE=docker.io/eclipse-temurin:17-jdk
ARG PROD_IMAGE=docker.io/eclipse-temurin:17-jre-jammy
# Build stage
FROM $BUILD_IMAGE AS builder

#Tag
ARG PROJECT_BUILD_VERSION="0.0.1-SNAPSHOT-local"
ENV PROJECT_BUILD_VERSION=${PROJECT_BUILD_VERSION}

WORKDIR /workspace

# Copy wrapper and configuration files
COPY gradlew .
COPY gradle/ gradle/
COPY build.gradle settings.gradle ./

RUN chmod +x ./gradlew

# Pre cache of dependencies
RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon help || true

# Copy the rest of the source code
COPY . .
# Ensure the Gradle build receives the project version so the produced jar has the expected version
RUN --mount=type=cache,target=/root/.gradle \
	./gradlew bootJar \
	-Pprofile=prod \
	-PprojectBuildVersion=${PROJECT_BUILD_VERSION} \
	--no-daemon

# Production stage
FROM $PROD_IMAGE AS runtime

#Create a non-root user to run the application
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

COPY --from=builder /workspace/build/libs/*.jar app.jar

RUN chown appuser:appgroup app.jar
USER appuser

EXPOSE 3003

# Optimizations for running in containers
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["java", "-jar", "app.jar"]