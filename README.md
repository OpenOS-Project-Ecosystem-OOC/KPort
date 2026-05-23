[update-readmes]   Mode: rewrite — migrating to template structure...
# KPort

[![Built with Ona](https://ona.com/build-with-ona.svg)](https://app.ona.com/#https://github.com/Interested-Deving-1896/KPort)

<!-- AI:start:what-it-does -->
KPort provides a Portage-inspired package management system for KDE Neon, integrating features like USE flags, hardware compatibility layers for CPU/GPU/NPU, and automated pacscript generation. It is designed for developers and power users who need customizable package builds and enhanced hardware-specific optimizations.
<!-- AI:end:what-it-does -->

## Architecture

<!-- AI:start:architecture -->
KPort consists of modular components designed for package management and hardware compatibility. The repository integrates KDE Neon packaging with Pacstall, enabling USE flags and hardware-specific optimizations for CPU, GPU, and NPU. Automated workflows handle hardware detection, pacscript generation, and upstream contributions. The directory structure organizes scripts, configurations, and generated files for maintainability.

```plaintext
.
├── .devcontainer/         # Development container configuration
├── .github/               # GitHub Actions workflows
├── .gitlab-ci.yml         # GitLab CI pipeline configuration
├── bin/                   # Executable scripts for package management
├── config/                # Configuration files for build and runtime
├── db/                    # Metadata and database files for packages
├── dep-graph/             # Dependency graph generation and analysis
├── generated/             # Auto-generated pacscripts and related files
├── lib/                   # Shared library scripts
├── overlays/              # Custom package overlays
├── packages/              # Package definitions and metadata
├── scripts/               # Utility and automation scripts
└── README.md              # Project documentation
```

Components interact through shared libraries and workflows. Hardware detection triggers compatibility adjustments, while automated scripts generate and manage pacscripts based on KDE Neon packaging. CI pipelines ensure consistency and integration with upstream repositories.
<!-- AI:end:architecture -->

## Install

<!-- Add installation instructions here. This section is yours — the AI will not modify it. -->

```bash
git clone https://github.com/Interested-Deving-1896/KPort.git
cd KPort
```

## Usage

<!-- Add usage examples here. This section is yours — the AI will not modify it. -->

## Configuration

<!-- Document configuration options here. This section is yours — the AI will not modify it. -->

## CI

<!-- AI:start:ci -->
- `hardware-detect.yml`: Detects CPU, GPU, and NPU hardware compatibility layers. No secrets required.  
- `neon-build-ci.yml`: Builds KDE Neon-based packages using Pacstall and USE flags. No secrets required.  
- `notify-hw-detect-consumers.yml`: Sends notifications to dependent systems about hardware detection updates. Requires `WEBHOOK_URL` secret.  
- `pacscript-ci.yml`: Generates and validates pacscripts from KDE Neon packaging. No secrets required.  
<!-- AI:end:ci -->

## Mirror chain

<!-- AI:start:mirror-chain -->
This repo is maintained in [`Interested-Deving-1896/KPort`](https://github.com/Interested-Deving-1896/KPort) and mirrored through:

```
Interested-Deving-1896/KPort  ──►  OpenOS-Project-OSP/KPort  ──►  OpenOS-Project-Ecosystem-OOC/KPort
```

Changes flow downstream automatically via the hourly mirror chain in
[`fork-sync-all`](https://github.com/Interested-Deving-1896/fork-sync-all).
Direct commits to OSP or OOC are detected and opened as PRs back to `Interested-Deving-1896`.
<!-- AI:end:mirror-chain -->

## Contributors

<!-- AI:start:contributors -->
[@Interested-Deving-1896](https://github.com/Interested-Deving-1896): 206 commits

*Note: This repository is a mirror. Please refer to the upstream source for the original project.*
<!-- AI:end:contributors -->

## Origins

<!-- AI:start:origins -->

KPort is an original project — a Portage-inspired package repository for KDE Neon using Pacstall.
It was created from the following upstream inspirations:

| Origin | Host | Fork in I-D-1896 |
|--------|------|-----------------|
| [KDE/neon-neon-repositories](https://github.com/KDE/neon-neon-repositories) | GitHub | ✅ |
| [neon/ubuntu-core](https://invent.kde.org/neon/ubuntu-core) | KDE Invent | ✅ |
| [neon/pkg-kde-tools](https://invent.kde.org/neon/pkg-kde-tools) | KDE Invent | ✅ |
| [neon/pkg-kde-jenkins](https://invent.kde.org/neon/pkg-kde-jenkins) | KDE Invent | ✅ |
| [neon/pkg-kde-dev-scripts](https://invent.kde.org/neon/pkg-kde-dev-scripts) | KDE Invent | ✅ |
| [neon/docker-images](https://invent.kde.org/neon/docker-images) | KDE Invent | ✅ |
| [neon/qt-kde-team.pages.debian.net](https://invent.kde.org/neon/qt-kde-team.pages.debian.net) | KDE Invent | ✅ |
| [gentoo/portage](https://github.com/gentoo/portage) | GitHub | ✅ |
| [pacstall/pacstall](https://github.com/pacstall/pacstall) | GitHub | ✅ |
| [KDE/craft](https://github.com/KDE/craft) | GitHub | ✅ |
| [KDE/craft-blueprints-kde](https://github.com/KDE/craft-blueprints-kde) | GitHub | ✅ |
| [KDE/craft-blueprints-community](https://github.com/KDE/craft-blueprints-community) | GitHub | ✅ |
| [KDE/kde-builder](https://github.com/KDE/kde-builder) | GitHub | ✅ |
| [KDE/kdesrc-build](https://github.com/KDE/kdesrc-build) | GitHub | ✅ |
| [KDE/kde-build-metadata](https://github.com/KDE/kde-build-metadata) | GitHub | ✅ |
| [KDE/kdevplatform](https://github.com/KDE/kdevplatform) | GitHub | ✅ |
| [KDE/superbuild](https://github.com/KDE/superbuild) | GitHub | ✅ |
| [KDE/android-builder](https://github.com/KDE/android-builder) | GitHub | ✅ |
<!-- AI:end:origins -->

## Resources

<!-- AI:start:resources -->
| File | Description |
|---|---|
| [dep-graph/origins.md](https://github.com/Interested-Deving-1896/KPort/blob/main/dep-graph/origins.md) | Dependency graph (Markdown table) |
| [.gitlab/merge_request_templates/Default.md](https://github.com/Interested-Deving-1896/KPort/blob/main/.gitlab/merge_request_templates/Default.md) | GitLab MR template |
<!-- AI:end:resources -->

## License

<!-- AI:start:license -->
[MIT](https://github.com/Interested-Deving-1896/KPort/blob/main/LICENSE) © 2026 [Interested-Deving-1896](https://github.com/Interested-Deving-1896)
<!-- AI:end:license -->
