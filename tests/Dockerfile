FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PROFILE=personal

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create test user with sudo
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Copy dotfiles
COPY --chown=testuser:testuser . /home/testuser/dotfiles

# Set working directory
WORKDIR /home/testuser/dotfiles

CMD ["/bin/bash"]
