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
      python3.10-venv \
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
WORKDIR /workspace
RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

# Creating and activating venv
WORKDIR /workspace/stable-diffusion-webui

# Install A1111 dependencies
RUN python3 -m venv /workspace/venv
RUN source /workspace/venv/bin/activate
RUN pip3 install --no-cache-dir torch==2.1.2+cu118 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
RUN pip3 install --no-cache-dir xformers==0.0.23.post1 --index-url https://download.pytorch.org/whl/cu118

COPY install-automatic.py .
RUN python3 -m install-automatic --skip-torch-cuda-test
COPY webui-user.sh .
COPY config.json .
COPY ui-config.json .
COPY models/Checkpoints/. models/Stable-diffusion/
COPY models/Lora/. models/Lora/
COPY models/VAE/. models/VAE/
COPY scripts/cache.py .

# Build cache for each model
RUN for file in models/Stable-diffusion/*.safetensors; do \
        python3 cache.py --use-cpu=all --ckpt "$file"; \
    done

RUN pip3 install huggingface_hub runpod

WORKDIR /

# Add RunPod Handler and Docker container start script
COPY start.sh rp_handler.py ./
COPY schemas /schemas

# Start the container
RUN chmod +x /start.sh
ENTRYPOINT /start.sh
