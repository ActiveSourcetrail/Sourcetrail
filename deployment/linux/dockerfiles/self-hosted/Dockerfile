# syntax=docker/dockerfile:1.4
# escape=`

# Here-Documents
# https://docs.docker.com/engine/reference/builder/#here-documents
# BuildKit only supports building Linux containers. Windows support is tracked in moby/buildkit#616


# ----------------------------------------------------------------------------
# Last Modified 10/13/2023, DIGEST:sha256:c9cf959fd83770dfdefd8fb42cfef0761432af36a764c077aed54bbc5bb25368
ARG FROM_IMAGE=ubuntu:22.04

FROM ${FROM_IMAGE} AS gnuc-buildtools

WORKDIR /work/temp

SHELL ["/bin/bash", "-c"]

# Install build tools
RUN `
    apt-get update && apt-get install -y `
    `
    # Build essential `
    autoconf `
    build-essential  `
    curl `
    git `
    ninja-build `
    p7zip-full `
    pkg-config `
    python2 `
    python3 `
    python3-distutils `
    tar `
    sudo `
    unzip `
    wget `
    zip `
    `
    # For Java `
    openjdk-8-jdk `
    maven `
    `
    # For angle `
    libx11-dev `
    libxext-dev `
    libxi-dev `
    mesa-common-dev `
    `
    # For Qt `
    # https://doc.qt.io/qt-5/linux-requirements.html `
    '^libxcb.*-dev' `
    libgbm-dev `
    libgl1-mesa-dev `
    libglu1-mesa-dev `
    libsm-dev `
    libx11-xcb-dev `
    libxcb-icccm4 `
    libxcb-image0 `
    libxcb-keysyms1 `
    libxcb-render-util0 `
    libxcb-xinerama0 `
    libxi-dev `
    libxkbcommon-dev `
    libxkbcommon-x11-dev `
    libxrender-dev `
    `
    # For linuxdeploy `
    # https://github.com/linuxdeploy/linuxdeploy-plugin-qt `
    libfuse2 `
    file `
    imagemagick `
    dos2unix `
    && more

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

RUN `
    wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && `
    wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && `
    chmod +x linuxdeploy*.AppImage && `
    mkdir -p /opt/linuxdeploy && `
    mv linuxdeploy*.AppImage /opt/linuxdeploy/ && `
    more

RUN `
    wget https://github.com/Kitware/CMake/releases/download/v3.27.7/cmake-3.27.7-linux-x86_64.sh && `
    chmod +x cmake-3.27.7-linux-x86_64.sh && `
    mkdir -p /opt/cmake && `
    ./cmake-3.27.7-linux-x86_64.sh --prefix=/opt/cmake --skip-license --exclude-subdir && `
    rm cmake-3.27.7-linux-x86_64.sh && `
    more

ENV PATH=/opt/cmake/bin:${PATH}

# Install PowerShell 7.2+ for && and || operators
RUN `
    wget https://github.com/PowerShell/PowerShell/releases/download/v7.2.15/powershell-lts_7.2.15-1.deb_amd64.deb && `
    dpkg -i powershell-lts_7.2.15-1.deb_amd64.deb && `
    rm powershell-lts_7.2.15-1.deb_amd64.deb || `
    apt-get install -y -f || `
    more

RUN `
    git config --system core.longpaths true && `
    more

# ----------------------------------------------------------------------------
FROM gnuc-buildtools AS builder

WORKDIR /work

SHELL ["/bin/bash", "-c"]

# vcpkg binary caching file-based
ENV VCPKG_BINARY_CACHING_FILES=/work/source/build/.cache/vcpkg-files
ENV VCPKG_BINARY_SOURCES=${VCPKG_BINARY_SOURCES:-clear;files,${VCPKG_BINARY_CACHING_FILES},readwrite;}

# Copy source from the build context with .dockerignore
# Don't mount host source directly
COPY . source/

# "EOT" for $ substitution in run time
COPY <<-"EOT" /work/create-package.ps1
    # Configure
    $ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue';

    Write-Output "Environments variables:`n"
    Write-Output "  VCPKG_BINARY_SOURCES=${env:VCPKG_BINARY_SOURCES}"
    New-Item -ItemType Directory -Path ${env:VCPKG_BINARY_CACHING_FILES} -Force
    
    dos2unix source/script/download_python_indexer.sh
    dos2unix source/script/update_java_indexer.sh
    dos2unix source/deployment/linux/appimage/sourcetrail.desktop

    # Build/Package
    cd source
    cmake --preset x64-linux-release
    cmake --build ./build/x64-linux-release --target package
    cd ..
EOT

ENTRYPOINT [ `
    "pwsh", "-NoLogo", "-ExecutionPolicy", "Bypass", `
    "/work/create-package.ps1" `
]


# ----------------------------------------------------------------------------
FROM gnuc-buildtools AS runner

WORKDIR /work

SHELL ["/bin/bash", "-c"]

# https://github.com/ActiveSourcetrail/Sourcetrail/settings/actions/runners/new
# Linux/x64
RUN <<EOT bash
    # Create a folder
    mkdir actions-runner && cd actions-runner
    
    # Download the latest runner package
    curl -o actions-runner-linux-x64-2.310.2.tar.gz -L https://github.com/actions/runner/releases/download/v2.310.2/actions-runner-linux-x64-2.310.2.tar.gz
    
    # Optional: Validate the hash
    echo "fb28a1c3715e0a6c5051af0e6eeff9c255009e2eec6fb08bc2708277fbb49f93  actions-runner-linux-x64-2.310.2.tar.gz" | shasum -a 256 -c
    
    # Extract the installer
    tar xzf ./actions-runner-linux-x64-2.310.2.tar.gz
EOT

# https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners#programmatically-assign-labels
# "EOT" for $ substitution in run time
COPY <<-"EOT" /work/run-runner.ps1
    # Configure
    $ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue';
    
    Write-Output "Environments variables:`n"
    Write-Output "  VCPKG_DEFAULT_BINARY_CACHE=${env:VCPKG_DEFAULT_BINARY_CACHE}"
    Write-Output "  VCPKG_BINARY_SOURCES=${env:VCPKG_BINARY_SOURCES}"
    
    # Create the runner and start the configuration experience
    ${env:ACTIONS_RUNNER_HOOK_JOB_STARTED}="/work/cleanup-job.ps1"
    ${env:RUNNER_ALLOW_RUNASROOT}=1
    cd actions-runner
    ./config.sh --unattended --work /short --url ${env:URL} --token ${env:TOKEN} --replace --name ubuntu-22.04 --labels x64,linux
    
    # Last step, run it!
    ./run.sh
    more
EOT

# https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/running-scripts-before-or-after-a-job
# "EOT" for $ substitution in run time
COPY <<-"EOT" /work/cleanup-job.ps1
    # Configure
    $ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'
    
    Remove-Item -Force -Recurse ${env:GITHUB_WORKSPACE}/*
    more
EOT

ENTRYPOINT [ `
    "pwsh", "-NoLogo", "-ExecutionPolicy", "Bypass", `
    "/work/run-runner.ps1" `
]