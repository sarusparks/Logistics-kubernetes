FROM mysql:8.0.41

# Copy initialization scripts
COPY scripts/* /docker-entrypoint-initdb.d/

# Switch to root user for installation
USER root

# Install dnsutils using microdnf (for Oracle Linux-based images)
RUN microdnf install -y bind-utils

# Switch back to MySQL user for security
USER mysql
