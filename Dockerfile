ARG ARG_UBUNTU_BASE_IMAGE="ubuntu"
ARG ARG_UBUNTU_BASE_IMAGE_TAG="20.04"

FROM ${ARG_UBUNTU_BASE_IMAGE}:${ARG_UBUNTU_BASE_IMAGE_TAG}
WORKDIR /azp

ARG ARG_TARGETARCH=linux-x64
ARG ARG_VSTS_AGENT_VERSION=4.251.0

# Non-interactive APT
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    git \
    iputils-ping \
    jq \
    lsb-release \
    software-properties-common \
    wget \
    unzip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Upgrade base image
RUN apt-get update && apt-get -y upgrade

# Install OpenJDK 17
RUN apt-get update && apt-get install -y openjdk-17-jdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Download and extract Azure DevOps Agent
RUN echo "Downloading Azure DevOps Agent version ${ARG_VSTS_AGENT_VERSION} for ${ARG_TARGETARCH}"
RUN curl -LsS https://vstsagentpackage.azureedge.net/agent/${ARG_VSTS_AGENT_VERSION}/vsts-agent-${ARG_TARGETARCH}-${ARG_VSTS_AGENT_VERSION}.tar.gz | tar -xz

# Install Azure CLI & Azure DevOps extension
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
    && az extension add --name azure-devops \
    && rm -rf /var/lib/apt/lists/*

# Install yq
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && mv ./yq_linux_amd64 /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && mv ./kubectl /usr/bin/kubectl \
    && chmod +x /usr/bin/kubectl

# Install PowerShell
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb
RUN apt-get update \
    && apt-get install -y powershell

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update \
    && apt-get install -y docker-ce-cli

# Copy start script
COPY ./start.sh .
RUN chmod +x start.sh

# Create non-root user under docker group
RUN useradd -m -s /bin/bash -u "1000" azdouser \
    && groupadd docker && usermod -aG docker azdouser \
    && echo azdouser ALL=\(root\) NOPASSWD:ALL >> /etc/sudoers

# Set ownership
RUN sudo chown -R azdouser /home/azdouser \
    && sudo chown -R azdouser /azp \
    && sudo chown -R azdouser /var/run/docker.sock || true

USER azdouser
WORKDIR /azp
ENTRYPOINT ["./start.sh"]
