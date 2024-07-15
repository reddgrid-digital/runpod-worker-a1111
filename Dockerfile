FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on \
    PIP_ROOT_USER_ACTION=ignore \
    SHELL=/bin/bash

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

# Upgrade apt packages and install required dependencies
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      git \
      software-properties-common \
      curl \
      build-essential \
      vim \
      python3-dev \
      python3-pip \
      fonts-dejavu-core \
      rsync \
      jq \
      moreutils \
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

# Install miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

# Clone A1111 repo to /workspace
WORKDIR /workspace
RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

# Set stable-diffusion-webui dir
WORKDIR /workspace/stable-diffusion-webui

# Create virtual environment
RUN conda create -n sd python=3.10.6 -y

# Make RUN commands use the new environment:
RUN conda init bash
SHELL ["conda", "run", "-n", "sd", "/bin/bash", "-c"]

RUN python --version

# Install Worker dependencies
RUN python -m pip install requests runpod huggingface_hub

# Install A1111 dependencies
RUN python -m pip install --no-cache-dir -r requirements.txt
RUN python -m pip install --no-cache-dir xformers==0.0.25
RUN python -m pip install --no-cache-dir torch==2.2.2 torchvision==0.17.2

COPY webui-user.sh .
COPY config.json .
COPY ui-config.json .
COPY models/Checkpoints/. models/Stable-diffusion/
COPY models/Lora/. models/Lora/
COPY models/VAE/. models/VAE/

WORKDIR /

# Test run and create cache
ENV PYTHONUNBUFFERED=true \
    HF_HOME="/workspace"

RUN timeout 3000 python /workspace/stable-diffusion-webui/webui.py \
  --use-cpu=all \
  --no-half \
  --skip-python-version-check \
  --skip-torch-cuda-test \
  --lowram \
  --opt-sdp-attention \
  --disable-safe-unpickle \
  --port 3000 \
  --api \
  --nowebui \
  --skip-version-check \
  --no-hashing \
  --no-download-sd-model

# Add RunPod Handler and Docker container start script
COPY start.sh rp_handler.py ./
COPY schemas /schemas

# Start the container
RUN chmod +x /start.sh
ENTRYPOINT /start.sh
