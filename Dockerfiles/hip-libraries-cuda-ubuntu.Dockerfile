# CUDA based docker image
FROM nvidia/cuda:11.6.2-devel-ubuntu20.04

# Base packages that are required for the installation
RUN export DEBIAN_FRONTEND=noninteractive; \
    apt-get update -qq \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        git \
        locales-all \
        make \
        python3 \
        ssh \
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Install HIP using the installer script
RUN export DEBIAN_FRONTEND=noninteractive; \
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add - \
    && echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.2/ ubuntu main' > /etc/apt/sources.list.d/rocm.list \
    && apt-get update -qq \
    && apt-get install -y hip-base hipify-clang \
    && apt-get download hip-runtime-nvidia hip-dev \
    && dpkg -i --ignore-depends=cuda hip*

# Install CMake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.21.7/cmake-3.21.7-linux-x86_64.sh \
    && mkdir /cmake \
    && sh cmake-3.21.7-linux-x86_64.sh --skip-license --prefix=/cmake \
    && rm cmake-3.21.7-linux-x86_64.sh

ENV PATH="/cmake/bin:/opt/rocm/bin:${PATH}"

RUN echo "/opt/rocm/lib" >> /etc/ld.so.conf.d/rocm.conf \
    && ldconfig

# Install rocRAND
RUN wget https://github.com/ROCmSoftwarePlatform/rocRAND/archive/refs/tags/rocm-5.2.0.tar.gz \
    && tar -xf ./rocm-5.2.0.tar.gz \
    && rm ./rocm-5.2.0.tar.gz \
    && cmake -S ./rocRAND-rocm-5.2.0 -B ./rocRAND-rocm-5.2.0/build \
        -D CMAKE_MODULE_PATH=/opt/rocm/lib/cmake/hip \
        -D BUILD_HIPRAND=OFF \
        -D CMAKE_INSTALL_PREFIX=/opt/rocm \
    && cmake --build ./rocRAND-rocm-5.2.0/build --target install \
    && rm -rf ./rocRAND-rocm-5.2.0

# Install hipCUB
RUN wget https://github.com/ROCmSoftwarePlatform/hipCUB/archive/refs/tags/rocm-5.2.0.tar.gz \
    && tar -xf ./rocm-5.2.0.tar.gz \
    && rm ./rocm-5.2.0.tar.gz \
    && cmake -S ./hipCUB-rocm-5.2.0 -B ./hipCUB-rocm-5.2.0/build \
        -D CMAKE_MODULE_PATH=/opt/rocm/lib/cmake/hip \
        -D CMAKE_INSTALL_PREFIX=/opt/rocm \
    && cmake --build ./hipCUB-rocm-5.2.0/build --target install \
    && rm -rf ./hipCUB-rocm-5.2.0

# Add the render group and a user with sudo permissions for the container
RUN groupadd --system --gid 109 render \
    && useradd -Um -G sudo,video,render developer \
    && echo developer ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/developer \
    && chmod 0440 /etc/sudoers.d/developer

RUN mkdir /workspaces && chown developer:developer /workspaces
WORKDIR /workspaces
VOLUME /workspaces

USER developer