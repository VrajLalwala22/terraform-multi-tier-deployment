FROM node:20-alpine

# Install required tools including Terraform
RUN apk update && apk add --no-cache wget unzip ca-certificates git curl && \
    wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip && \
    unzip terraform_1.7.0_linux_amd64.zip -d /usr/local/bin/ && \
    rm terraform_1.7.0_linux_amd64.zip

WORKDIR /app

# Install Node modules
COPY package.json package-lock.json* ./
RUN npm install

# Copy application files
COPY . .

# Required for Terraform execution inside Next.js process
ENV PATH="/usr/local/bin:${PATH}"

# Build the Next.js frontend
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
