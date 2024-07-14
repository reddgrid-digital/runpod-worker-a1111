FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on \
    SHELL=/bin/bash

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

# Upgrade apt packages and install required dependencies
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      python3-dev \
      python3-pip \
      fonts-dejavu-core \
      rsync \
      git \
      jq \
      moreutils \
      aria2 \
      wget \
      curl \
      libglib2.0-0 \
      libsm6 \
      libgl1 \
      libxrender1 \
      libxext6 \
      ffmpeg \
      bc \
      libgoogle-perftools4 \
      libtcmalloc-minimal4 \
      procps && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -y

# Set Python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Install Worker dependencies
RUN pip install requests runpod huggingface_hub

# Clone A1111 repo to /workspace
RUN cd /workspace
RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

# "Creating and activating venv"
RUN cd stable-diffusion-webui
RUN python3 -m venv /workspace/venv
RUN source /workspace/venv/bin/activate

# "Installing Torch"
RUN pip3 install --no-cache-dir torch==2.1.2+cu118 torchvision torchaudio --index-url
RUN https://download.pytorch.org/whl/cu118

# "Installing xformers"
RUN pip3 install --no-cache-dir xformers==0.0.23.post1 --index-url https://download.pytorch.org/whl/cu118

# "Installing A1111 Web UI"
RUN wget https://raw.githubusercontent.com/reddgrid-digital/runpod-worker-a1111/main/install-automatic.py
RUN python3 -m install-automatic --skip-torch-cuda-test

# "Installing RunPod Serverless dependencies"
RUN cd /workspace/stable-diffusion-webui
RUN pip3 install huggingface_hub runpod

# "Creating log directory"
RUN mkdir -p /workspace/logs

# "Installing config files"
RUN cd /workspace/stable-diffusion-webui
RUN rm webui-user.sh config.json ui-config.json
RUN wget https://raw.githubusercontent.com/reddgrid-digital/runpod-worker-a1111/main/webui-user.sh
RUN wget https://raw.githubusercontent.com/reddgrid-digital/runpod-worker-a1111/main/config.json
RUN wget https://raw.githubusercontent.com/reddgrid-digital/runpod-worker-a1111/main/ui-config.json

# Add RunPod Handler and Docker container start script
COPY start.sh rp_handler.py ./
COPY schemas /schemas

# Start the container
RUN chmod +x /start.sh
ENTRYPOINT /start.sh
