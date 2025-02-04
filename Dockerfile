# Step 1: Installer Stage
FROM node:20-buster as installer

# Copy application code
COPY . /juice-shop

# Set working directory
WORKDIR /juice-shop

# Install global dependencies
RUN npm i -g typescript ts-node

# Install application dependencies
RUN npm install --omit=dev --unsafe-perm

# Debugging: Verify npm install and list dependencies
RUN npm list || echo "npm list failed"  # Will print an error message if dependencies are missing

# Clean up unnecessary frontend files
RUN rm -rf frontend/node_modules
RUN rm -rf frontend/.angular
RUN rm -rf frontend/src/assets

# Create logs directory and set permissions
RUN mkdir logs
RUN chown -R 65532 logs
RUN chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/
RUN chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/

# Remove optional files
RUN rm data/chatbot/botDefaultTrainingData.json || true
RUN rm ftp/legal.md || true
RUN rm i18n/*.json || true

# Install CycloneDX globally (pinned version for stability)
ARG CYCLONEDX_NPM_VERSION=1.4.0
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION

# Debugging: Verify CycloneDX installation
RUN cyclonedx-npm --version

# Run the SBOM script and debug output
RUN ls -la /juice-shop
RUN npm list || echo "npm list failed"

# Capture detailed debug output for sbom run
RUN echo "Running sbom script..." && npm run sbom || echo "npm run sbom failed"

# Step 2: Build libxmljs to resolve startup error
FROM node:20-buster as libxmljs-builder
WORKDIR /juice-shop
RUN apt-get update && apt-get install -y build-essential python3
COPY --from=installer /juice-shop/node_modules ./node_modules
RUN rm -rf node_modules/libxmljs/build && \
    cd node_modules/libxmljs && \
    npm run build

# Step 3: Final Stage
FROM gcr.io/distroless/nodejs20-debian11

# Arguments for metadata
ARG BUILD_DATE
ARG VCS_REF

# Metadata labels
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

# Set working directory
WORKDIR /juice-shop

# Copy necessary files from installer and libxmljs-builder stages
COPY --from=installer --chown=65532:0 /juice-shop .
COPY --chown=65532:0 --from=libxmljs-builder /juice-shop/node_modules/libxmljs ./node_modules/libxmljs

# Set unprivileged user
USER 65532

# Expose application port
EXPOSE 3000

# Start the application
CMD ["/juice-shop/build/app.js"]
