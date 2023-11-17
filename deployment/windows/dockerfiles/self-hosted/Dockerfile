# escape=`

# Here-Documents
# https://docs.docker.com/engine/reference/builder/#here-documents
# BuildKit only supports building Linux containers. Windows support is tracked in moby/buildkit#616


# ----------------------------------------------------------------------------
# Last Modified 10/11/2023, Digest:sha256:2173a3e2b0c4d9f77bb32846c36c0e9fe27813fe2f19ad868fb5f891486bbc7e
ARG FROM_IMAGE=mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

FROM ${FROM_IMAGE} AS msvc-buildtools

WORKDIR c:/work/temp

SHELL ["cmd", "/S", "/C"]

# Install PowerShell 7.2+ for && and || operators
RUN `
    powershell -Command "Start-Sleep -Seconds 10"; `
    curl.exe -fSLo PowerShellInstaller.msi https://github.com/PowerShell/PowerShell/releases/download/v7.2.14/PowerShell-7.2.14-win-x64.msi && `
    msiexec /i PowerShellInstaller.msi /qn /norestart && `
    del /q PowerShellInstaller.msi && `
    more

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

# Current Channel
ARG VS_RELEASE_CHANNEL_URL=https://aka.ms/vs/17/release

# Installing Build Tools for Visual Studio
RUN `
    Start-Sleep -Seconds 10; `
    Invoke-WebRequest -OutFile VSCollect.exe https://aka.ms/vscollect.exe -UseBasicParsing; `
    Invoke-WebRequest -OutFile VSBuildTools.exe ${env:VS_RELEASE_CHANNEL_URL}/vs_buildtools.exe -UseBasicParsing; `
    Invoke-WebRequest -OutFile ChannelManifest.json ${env:VS_RELEASE_CHANNEL_URL}/channel -UseBasicParsing; `
    `
    # https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
    $Arguments = """ `
        --quiet --wait --norestart --nocache install `
        --installPath C:/BuildTools `
        --channelUri file:///${pwd}/ChannelManifest.json `
        --installChannelUri file:///${pwd}/ChannelManifest.json `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.VC.ATL `
        --add Microsoft.VisualStudio.Component.VC.ATLMFC `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.20348 `
        --add Microsoft.VisualStudio.Component.VC.v141.ATL `
        --add Microsoft.VisualStudio.Component.VC.v141.MFC `
        --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 `
    """; `
    $Process = (Start-Process -Wait -PassThru -Path "./VSBuildTools.exe" -ArgumentList $Arguments); `
    if (($Process.ExitCode -eq 0) -or ($Process.ExitCode -eq 3010)) `
    { `
        Remove-Item -Force VSCollect.exe; `
        Remove-Item -Force VSBuildTools.exe; `
        Remove-Item -Force ChannelManifest.json; `
        Remove-Item -Force -Recurse ${env:TEMP}/*; `
        return 0; `
    } `
    else `
    { `
        New-Item ${pwd}/Logs -ItemType Directory; `
        (& "./VSCollect.exe" -zip:${pwd}/Logs/VSCollect.InstallLogs.zip); `
        return $Process.ExitCode; `
    }

# Install Chocolatey
RUN `
    # Requirements .NET Framework 4.8
    (Get-ItemPropertyValue -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release) -ge 528040; `
    # Download 
    Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));

# Install Utilities
RUN `
    choco install git --version 2.42.0 -y --params "'/GitAndUnixToolsOnPath /NoAutoCrlf'"; `
    choco install cmake --version 3.27.7 -y --installargs 'ADD_CMAKE_TO_PATH=User'; `
    choco install ninja --version 1.11.1 -y; `
    choco install python --version 3.12.0 -y; `
    choco install python2 -y; `
    choco install jdk8 --version 8.0.211 -y; `
    choco install maven --version 3.9.5 -y; `
    choco install 7zip --version 23.1.0 -y; `
    Import-Module ${env:ChocolateyInstall}/helpers/chocolateyProfile.psm1; `
    Update-SessionEnvironment; `
    Remove-Item -Force -Recurse ${env:TEMP}/chocolatey; `
    more

RUN `
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force; `
    git config --system core.longpaths true; `
    more

# ----------------------------------------------------------------------------
FROM msvc-buildtools AS builder

WORKDIR c:/work

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

ENV MSVC_VERSION=${MSVC_VERSION:-14.16}

# vcpkg binary caching file-based
ENV VCPKG_BINARY_CACHING_FILES=c:/work/source/build/.cache/vcpkg-files
ENV VCPKG_BINARY_SOURCES=${VCPKG_BINARY_SOURCES:-clear;files,${VCPKG_BINARY_CACHING_FILES},readwrite;}

# Copy source from the build context with .dockerignore
# Don't mount host source directly
COPY . source/

RUN Set-Content -Path c:/work/create-package.ps1 -Value ' `
    # Configure
    $ErrorActionPreference = """Stop"""; $ProgressPreference = """Continue"""; `
    `
    Import-Module "C:/BuildTools/Common7/Tools/Microsoft.VisualStudio.DevShell.dll"; `
    Enter-VsDevShell -InstallPath "C:/BuildTools" -SkipAutomaticLocation -DevCmdArguments """-arch=x64 -host_arch=x64 -vcvars_ver=${env:MSVC_VERSION}"""; `
    `
    Write-Output "Environments variables:`n"; `
    Write-Output "  VCPKG_BINARY_SOURCES=${env:VCPKG_BINARY_SOURCES}"; `
    New-Item -ItemType Directory -Path ${env:VCPKG_BINARY_CACHING_FILES} -Force; `
    `
    # Build/Package
    cd source; `
    cmake --preset x64-windows-release; `
    cmake --build ./build/x64-windows-release --target package; `
    cd ..; `
'

ENTRYPOINT [ `
    "pwsh", "-NoLogo", "-ExecutionPolicy", "Bypass", `
    "c:/work/create-package.ps1" `
]


# ----------------------------------------------------------------------------
FROM msvc-buildtools AS runner

WORKDIR c:/work

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

# Installing vswhere for github actions TheMrMilchmann/setup-msvc-dev
RUN `
    Invoke-WebRequest -OutFile C:/BuildTools/vswhere.exe https://github.com/microsoft/vswhere/releases/download/3.1.7/vswhere.exe -UseBasicParsing; `
    [Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:/BuildTools', 'Machine'); `
    more

# https://github.com/ActiveSourcetrail/Sourcetrail/settings/actions/runners/new
# Windows/x64
RUN `
    # Create a folder under the drive root
    mkdir actions-runner; cd actions-runner; `
    `
    # Download the latest runner package
    Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.310.2/actions-runner-win-x64-2.310.2.zip -OutFile actions-runner-win-x64-2.310.2.zip; `
    `
    # Optional: Validate the hash
    if((Get-FileHash -Path actions-runner-win-x64-2.310.2.zip -Algorithm SHA256).Hash.ToUpper() -ne 'cc4c9e357345a33bd99834daaf2e051730305e0a4e33e5a6b47d39e6a93844e4'.ToUpper()){ throw 'Computed checksum did not match' }; `
    `
    # Extract the installer
    Add-Type -AssemblyName System.IO.Compression.FileSystem ; `
    [System.IO.Compression.ZipFile]::ExtractToDirectory("""${pwd}/actions-runner-win-x64-2.310.2.zip""", ${pwd}); `
    more

RUN Set-Content -Path c:/work/run-runner.ps1 -Value ' `
    # Configure
    $ErrorActionPreference = """Stop"""; $ProgressPreference = """Continue"""; `
    `
    Write-Output "Environments variables:`n"; `
    Write-Output "  VCPKG_DEFAULT_BINARY_CACHE=${env:VCPKG_DEFAULT_BINARY_CACHE}"; `
    Write-Output "  VCPKG_BINARY_SOURCES=${env:VCPKG_BINARY_SOURCES}"; `
    `
    # Create the runner and start the configuration experience
    ${env:ACTIONS_RUNNER_HOOK_JOB_STARTED}="""c:/work/cleanup-job.ps1"""; `
    ${env:RUNNER_ALLOW_RUNASROOT}=1; `
    cd actions-runner; `
    ./config.cmd --unattended --work c:/short --url ${env:URL} --token ${env:TOKEN} --replace --name windows-2019 --labels x64,windows; `
    `
    # Last step, run it!
    ./run.cmd; `
    more `
'

# https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/running-scripts-before-or-after-a-job
RUN Set-Content -Path c:/work/cleanup-job.ps1 -Value ' `
    # Configure
    $ErrorActionPreference = """Stop"""; $ProgressPreference = """Continue"""; `
    `
    Remove-Item -Force -Recurse ${env:GITHUB_WORKSPACE}/*; `
    more `
'

ENTRYPOINT [ `
    "pwsh", "-NoLogo", "-ExecutionPolicy", "Bypass", `
    "c:/work/run-runner.ps1" `
]