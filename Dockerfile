# syntax=docker/dockerfile:1.7

FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_BLENDER=true
ARG NODE_MAJOR=20
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu128

ENV CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/cuda/bin:/workspace/.venv/bin:/usr/local/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH} \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,video \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=0 \
    PIP_EXTRA_INDEX_URL=https://pypi.nvidia.com \
    FORCE_CUDA=1 \
    TORCH_CUDA_ARCH_LIST=9.0 \
    MAX_JOBS=8 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    arch="$(dpkg --print-architecture)"; \
    test "${arch}" = "arm64"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl wget git git-lfs openssh-client gnupg lsb-release \
        software-properties-common pkg-config build-essential gcc g++ gfortran make \
        cmake ninja-build autoconf automake libtool patch patchelf \
        python3 python3-dev python3-pip python3-setuptools python3-venv \
        python3-wheel python-is-python3 ffmpeg \
        libgl1 libglvnd-dev libegl1 libegl-dev libgles2 libgles-dev \
        libosmesa6-dev libglib2.0-0 libsm6 libxext6 libxrender1 \
        libx11-6 libx11-dev libxi6 libxi-dev libxrandr2 libxrandr-dev \
        libxinerama1 libxinerama-dev libxcursor1 libxcursor-dev \
        libxxf86vm1 libxxf86vm-dev libxkbcommon-x11-0 libgtk-3-0 libgtk-3-dev \
        libjpeg-dev libpng-dev libtiff-dev libopenexr-dev zlib1g-dev \
        libffi-dev libssl-dev libopenblas-dev liblapack-dev libeigen3-dev \
        libboost-all-dev libsuitesparse-dev libceres-dev libopencv-dev libhdf5-dev; \
    git lfs install --system

RUN set -eux; \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    npm install -g npm@latest

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if [ "${INSTALL_BLENDER}" = "true" ]; then \
        if ! apt-get update || ! apt-get install -y --no-install-recommends blender; then \
            apt-get update; \
            apt-get install -y --no-install-recommends \
                subversion libepoxy-dev libopenal-dev libsndfile1-dev \
                libopenimageio-dev libopenjp2-7-dev libopenvdb-dev libalembic-dev \
                libembree-dev libtbb-dev libyaml-cpp-dev libzstd-dev; \
            git clone --depth 1 --branch v4.1.1 https://projects.blender.org/blender/blender.git /tmp/blender; \
            git -C /tmp/blender submodule update --init --recursive --depth 1; \
            cmake -S /tmp/blender -B /tmp/blender-build -G Ninja \
                -DCMAKE_BUILD_TYPE=Release \
                -DWITH_HEADLESS=ON \
                -DWITH_X11=OFF \
                -DWITH_INSTALL_PORTABLE=OFF; \
            cmake --build /tmp/blender-build --target install --parallel "$(nproc)"; \
            rm -rf /tmp/blender /tmp/blender-build; \
        fi; \
    fi

RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    python -m pip install --upgrade pip setuptools wheel build cmake ninja packaging pybind11 cython numpy

RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    python -m pip install --index-url "${TORCH_INDEX_URL}" --extra-index-url https://pypi.nvidia.com torch torchvision torchaudio || \
    python -m pip install --extra-index-url https://pypi.nvidia.com torch torchvision torchaudio || \
    python -m pip install --no-binary=:all: torch torchvision torchaudio

COPY . /workspace

RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    if ls requirements*.txt >/dev/null 2>&1; then \
        for req in requirements*.txt; do \
            python -m pip install --no-build-isolation -r "${req}" || python -m pip install --no-build-isolation --no-binary=:all: -r "${req}"; \
        done; \
    fi; \
    if [ -d submodules/diff-gaussian-rasterization ]; then \
        python -m pip install --no-build-isolation -e submodules/diff-gaussian-rasterization; \
    fi; \
    if [ -f pyproject.toml ] || [ -f setup.py ]; then \
        python -m pip install --no-build-isolation -e . || python -m pip install --no-build-isolation --no-binary=:all: -e .; \
    fi

ARG NAS3R_MULTIVIEW_CHECKPOINT_URL=https://huggingface.co/RanranHuang/NAS3R/resolve/main/re10k_nas3r_multiview.ckpt
RUN --mount=type=cache,target=/root/.cache/nas3r-checkpoints \
    set -eux; \
    mkdir -p checkpoints; \
    if [ ! -s /root/.cache/nas3r-checkpoints/re10k_nas3r_multiview.ckpt ]; then \
        curl -fL "${NAS3R_MULTIVIEW_CHECKPOINT_URL}" -o /root/.cache/nas3r-checkpoints/re10k_nas3r_multiview.ckpt; \
    fi; \
    cp /root/.cache/nas3r-checkpoints/re10k_nas3r_multiview.ckpt checkpoints/re10k_nas3r_multiview.ckpt

RUN --mount=type=cache,target=/root/.npm \
    set -eux; \
    if [ -f package.json ]; then \
        if [ -f package-lock.json ]; then npm ci; else npm install; fi; \
    fi; \
    if [ -f web/frontend/package.json ]; then \
        cd web/frontend; \
        if [ -f package-lock.json ]; then npm ci; else npm install; fi; \
    fi

CMD ["/bin/bash"]
