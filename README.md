[update-readmes]   Mode: rewrite — migrating to template structure...
# KPort

[![Built with Ona](https://ona.com/build-with-ona.svg)](https://app.ona.com/#https://github.com/OpenOS-Project-OSP/KPort) [![KDE Eco](https://img.shields.io/badge/KDE%20Eco-certified-brightgreen?logo=kde&logoColor=white&style=flat-square)](https://eco.kde.org/) [![Blue Angel](https://img.shields.io/badge/Blue%20Angel-DE--UZ%20215-0055a4?style=flat-square)](https://www.blauer-engel.de/en/certification/criteria)



<!-- AI:start:what-it-does -->
KPort provides a Portage-inspired package repository for KDE Neon, integrating Pacstall with support for USE flags and hardware compatibility layers for CPU, GPU, and NPU. It automates pacscript generation from KDE Neon packaging, enabling developers and advanced users to customize and optimize software builds for specific hardware configurations.
<!-- AI:end:what-it-does -->

## Architecture

<!-- AI:start:architecture -->
KPort consists of modular components for managing KDE Neon packages with Pacstall, leveraging USE flags and hardware compatibility layers. The repository automates pacscript generation and integrates workflows for CI/CD, hardware detection, and repository synchronization. Key components include:

- `bin/`: Executables for package management and script utilities.
- `config/`: Configuration files for repository and build settings.
- `db/`: Metadata and dependency information for packages.
- `generated/`: Auto-generated pacscripts and related files.
- `lib/`: Shared libraries and helper scripts.
- `overlays/`: Custom package overlays for specific configurations.
- `packages/`: Source definitions for KDE Neon packages.
- `scripts/`: Automation scripts for tasks like hardware detection and CI.
- `vendor/`: External dependencies and third-party tools.

Workflows in `.github/workflows/` handle tasks such as syncing with GitLab, detecting hardware, building packages, and maintaining pacscripts.

Directory structure:
```plaintext
.
├── .github/
│   └── workflows/
├── bin/
├── config/
├── db/
├── dep-graph/
├── generated/
├── lib/
├── overlays/
├── packages/
├── scripts/
└── vendor/
```
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
- **check-gitlab-sync.yml**: Verifies synchronization between this repository and a GitLab mirror. No secrets required.  
- **hardware-detect.yml**: Detects CPU, GPU, and NPU hardware compatibility layers. Requires `HW_DETECT_API_KEY` secret.  
- **neon-build-ci.yml**: Builds and tests KDE Neon packages for compatibility. Requires `NEON_CI_TOKEN` secret.  
- **notify-hw-detect-consumers.yml**: Notifies downstream consumers of hardware detection updates. Requires `WEBHOOK_URL` secret.  
- **pacscript-ci.yml**: Validates and generates pacscripts from KDE Neon packaging. No secrets required.  
- **rebase-prs.yml**: Automatically rebases open pull requests on the latest `main` branch. No secrets required.  
- **update-kde-builder-vendor.yml**: Updates vendor dependencies for KDE Neon package building. No secrets required.  
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
[@Interested-Deving-1896](https://github.com/Interested-Deving-1896): 366 commits

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
<!-- AI:end:resources -->

## License

<!-- AI:start:license -->
[MIT](https://github.com/Interested-Deving-1896/KPort/blob/main/LICENSE) © 2026 [Interested-Deving-1896](https://github.com/Interested-Deving-1896)
<!-- AI:end:license -->
