FROM node:20-slim

WORKDIR /app

# Install required tools: docker CLI, curl, git, nomad
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Nomad CLI
RUN curl -Lo nomad.zip https://releases.hashicorp.com/nomad/1.7.2/nomad_1.7.2_linux_amd64.zip \
    && unzip nomad.zip -d /usr/local/bin/ \
    && rm nomad.zip \
    && chmod +x /usr/local/bin/nomad

# Install jq for JSON processing
RUN curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o /usr/local/bin/jq \
    && chmod +x /usr/local/bin/jq

# Install dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy application
COPY server.js ./

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); })"

CMD ["node", "server.js"]
