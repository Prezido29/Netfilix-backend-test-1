# ================================
# Stage 1: Build
# ================================
FROM eclipse-temurin:17-jdk AS builder

# Install Maven
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy pom.xml first (leverages Docker layer caching - dependencies won't
# re-download unless pom.xml changes)
COPY pom.xml .

# Download all dependencies in a separate layer
RUN mvn dependency:go-offline -B

# Copy source code and config
COPY ./src ./src
COPY application.properties ./src/main/resources/application.properties

# Build the JAR (skip tests here; tests run in the CI pipeline separately)
RUN mvn clean package -DskipTests


# ================================
# Stage 2: Runtime
# ================================
FROM eclipse-temurin:17-jre AS runtime

# Create a non-root user for security best practices
RUN groupadd --system appgroup && useradd --system --gid appgroup appuser

# Set working directory
WORKDIR /app

# Copy only the built JAR from the builder stage
# Nothing else (no Maven, no JDK, no source code) ends up in the final image
COPY --from=builder /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown appuser:appgroup app.jar

# Switch to non-root user
USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]