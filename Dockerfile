# Stage 1: Installer
FROM node:20-buster AS installer

# Copy application source code
COPY . /juice-shop

# Set the working directory
WORKDIR /juice-shop

# Install necessary tools globally
RUN npm install -g typescript ts-node

# Install dependencies, omitting dev dependencies for production
RUN npm install --omit=dev --unsafe-perm

# Remove duplicate dependencies
RUN npm dedupe --omit=dev

# Clean up unused directories to reduce image size
RUN rm -rf frontend/node_modules \
           frontend/.angular \
           frontend/src/assets

# Create logs directory with proper ownership and permissions
RUN mkdir logs && \
    chown -R 65532 logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/

# Remove unnecessary files, ensuring commands don't fail if files are absent
RUN rm -f data/chatbot/botDefaultTrainingData.json \
           ftp/legal.md \
           i18n/*.json

# Install CycloneDX NPM globally for SBOM generation
ARG CYCLONEDX_NPM_VERSION=latest
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION

# Debugging: Check if CycloneDX is installed
RUN npm list -g @cyclonedx/cyclonedx-npm

# Generate the Software Bill of Materials (SBOM)
RUN cyclonedx-npm --debug

# Stage 2: Build libxmljs
FROM node:20-buster AS libxmljs-builder

# Set the working directory
WORKDIR /juice-shop

# Install necessary tools and libraries for building libxmljs
RUN apt-get update && apt-get install -y build-essential python3

# Copy dependencies from the installer stage
COPY --from=installer /juice-shop/node_modules ./node_modules

# Rebuild libxmljs to avoid startup errors
RUN rm -rf node_modules/libxmljs/build && \
    cd node_modules/libxmljs && \
    npm run build

# Stage 3: Final production image
FROM gcr.io/distroless/nodejs20-debian11

# Define build arguments for image metadata
ARG BUILD_DATE
ARG VCS_REF

# Add metadata labels
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.title="OWASP Juice Shop" \
      org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
      org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.vendor="Open Worldwide Application Security Project" \
      org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="17.1.1" \
      org.opencontainers.image.url="https://owasp-juice.shop" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE

# Set the working directory
WORKDIR /juice-shop

# Copy the application files and built libxmljs from previous stages
COPY --from=installer --chown=65532:0 /juice-shop . 
COPY --chown=65532:0 --from=libxmljs-builder /juice-shop/node_modules/libxmljs ./node_modules/libxmljs

# Use a non-root user for better security
USER 65532

# Expose the application's default port
EXPOSE 3000

# Define the command to start the application
CMD ["/juice-shop/build/app.js"]
