# to make it run on macOS Docker-in-Docker (DinD) use: docker run --privileged -it --rm heroku-rootless-docker bash
FROM heroku/heroku:24

USER root

# Update package lists and install necessary packages for rootless Docker
RUN apt-get update \
      && apt-get install -y uidmap dbus-user-session curl ca-certificates gnupg lsb-release

# Add Docker's official GPG key
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
RUN apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a user for rootless Docker
RUN useradd -m -s /bin/bash rootlessuser

# Configure subuid and subgid for the user
RUN echo 'rootlessuser:100000:65536' >> /etc/subuid && \
    echo 'rootlessuser:100000:65536' >> /etc/subgid

# Set the user to rootlessuser
USER rootlessuser

# Add environment variables to .bashrc for rootless Docker
RUN echo 'export PATH=/home/rootlessuser/bin:$PATH' >> /home/rootlessuser/.bashrc && \
    echo 'export XDG_RUNTIME_DIR=$HOME/.docker/xrd' >> /home/rootlessuser/.bashrc && \
    echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> /home/rootlessuser/.bashrc

RUN rm -rf $HOME/.docker/xrd && mkdir -p $HOME/.docker/xrd

# Install rootless Docker extras if not already installed
RUN dockerd-rootless-setuptool.sh install --skip-iptables --force

# Set the working directory
WORKDIR /home/rootlessuser

# Command to run when the container starts
CMD ["/bin/bash", "-c", "source ~/.bashrc && dockerd-rootless.sh & sleep infinity"]