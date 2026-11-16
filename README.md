# Kali Tools Setup

**A reproducible starter toolkit for Kali Linux pentesting labs.**

Part of [PentestBlueprint](https://cybersecurity-blog.sayhi2tauseef.workers.dev/) — The Dark Codex. This Bash installer prepares a collection of Active Directory, network enumeration, pivoting, web assessment, and Windows lab utilities in one pass. Intended for **authorized labs and security assessments only**.

> **Status: unverified on a clean Kali installation.** Review the script and test in a disposable VM snapshot before relying on it. GitHub release URLs, APT package availability, and Python dependencies can change.

## What's included

| Category | Tools or components | Installation method |
| --- | --- | --- |
| Active Directory | NetExec, Impacket, Certipy, BloodHound Python collector, PKINITtools, pyWhisker, targetedKerberoast | Kali APT + isolated Python virtual environments |
| Attack-path analysis | BloodHound Community Edition CLI | Official GitHub release download; containers **not** started automatically |
| Enumeration | Nmap, RustScan, smbclient, LDAP tools, enum4linux-ng, dnsutils | Kali APT |
| Pivoting | Ligolo-ng v0.8.2 Linux proxy and Windows agent | GitHub release archives |
| Windows lab binaries | nc64.exe, Rubeus.exe, mimikatz.exe | Source repository downloads |
| Web testing | Gobuster, ffuf, feroxbuster, sqlmap, PHP reverse-shell reference | Kali APT + source download |
| Password and general utilities | Hashcat, John, Responder, SecLists, Evil-WinRM, rlwrap | Kali APT |
| Desktop and infrastructure | Terminator, Neo4j, Docker, Sublime Text | Kali APT + official Sublime Text APT repository |

## Requirements

- A recent **Kali Linux** installation with internet access.
- An ordinary user account with `sudo` access; **do not run the script as root**.
- Enough disk space for APT packages, Docker, and downloaded archives.
- Preferably a VM snapshot before first execution.
- The script supports Kali architectures detected by `dpkg`; pinned Ligolo downloads target **amd64**.

## Installation

### Option A — From this repository

```bash
git clone https://github.com/tauseef-ansari/kali-tools-setup.git
cd kali-tools-setup
chmod +x kalitoolssetup.sh
./kalitoolssetup.sh

### Option B — Already downloaded the script

```bash
cd ~/Downloads
chmod +x kalitoolssetup.sh
./kalitoolssetup.sh
```

**Review before executing:**

```bash
less kalitoolssetup.sh
bash -n kalitoolssetup.sh
```

## What the script does, in order

1. Confirms that the OS is Kali Linux and the current user is not root.
2. Creates `~/Tools` subdirectories and a timestamped log.
3. Updates APT metadata and installs available baseline packages individually.
4. Refreshes the `locate` database and configures the user's `~/.local/bin` path.
5. Downloads and extracts BloodHound CE CLI without starting containers.
6. Downloads and extracts the pinned Ligolo-ng Linux proxy and Windows agent.
7. Clones PKINITtools, pyWhisker, and targetedKerberoast into `~/Tools/source`.
8. Creates separate Python virtual environments and command wrappers for the AD helper tools.
9. Downloads Windows lab binaries and a PHP reference script.
10. Adds the Sublime Text APT source and installs the editor.
11. Checks selected commands, prints the log path, and reports failed steps.

## Directory layout

```text
~/Tools/
├── ad/
│   └── .venvs/                 # Isolated Python dependencies
├── bloodhound/                # BloodHound CE CLI archive and executable
├── logs/                      # Timestamped setup logs
├── pivoting/
│   ├── ligolo-proxy/
│   └── ligolo-agent-windows/
├── source/
│   ├── PKINITtools/
│   ├── pywhisker/
│   └── targetedKerberoast/
├── web/
│   └── php_reverse_shell.php
└── windows/
    ├── nc64.exe
    ├── Rubeus.exe
    └── mimikatz.exe
```

## Verify installation

Open a **new terminal** to refresh your `PATH`, then check:

```bash
command -v nxc
command -v rustscan
command -v nmap
command -v bloodhound-cli
command -v docker
command -v pywhisker
command -v targetedKerberoast
ls -lah ~/Tools/windows ~/Tools/pivoting
ls -lt ~/Tools/logs | head
```

Some command names may vary between Kali package versions. A missing command is a prompt to check the installation log, not necessarily proof that its package failed.

## BloodHound CE setup

BloodHound CE is **downloaded only**. Starting it is a separate action that requires a working Docker installation and Compose v2:

```bash
sudo systemctl enable --now docker
docker compose version
bloodhound-cli install
```

Depending on your Docker permissions, you may need to configure Docker access first. Follow the CLI prompts and store initial credentials securely. **Neo4j is a separate installation and is not required for BloodHound CE's container stack.**

## Logs and troubleshooting

The installer writes a log to `~/Tools/logs/setup-YYYYMMDD-HHMMSS.log` and prints a list of failed steps at the end.

```bash
ls -lt ~/Tools/logs/
tail -n 80 ~/Tools/logs/setup-*.log
```

If an APT package is unavailable, check `apt-cache policy PACKAGE_NAME`. If a GitHub download fails, verify its current release asset name. Re-running the script skips existing downloads and cloned repositories, but it can still repeat APT operations and Python dependency installation. It is **not** a fully transactional or version-pinned installer.

## Security notes

- Only run downloaded executables in **isolated, authorized lab environments**; Windows security tools may be flagged by endpoint protection.
- Inspect third-party source code and release assets before execution. The installer currently does **not** verify download checksums or signatures.
- The script modifies system packages and adds the Sublime Text APT repository.
- The script does **not** run a full system upgrade or start BloodHound containers automatically.
- Avoid publishing credentials, internal target addresses, or private assessment artifacts in issues or logs.

## Project files

- [`kalitoolssetup.sh`](./kalitoolssetup.sh) — the full Bash installer.
- [`README.md`](./README.md) — installation guide, package inventory, verification, and cautions.

## Credits

This installer automates installation of independent, third-party projects. All tools belong to their respective authors and maintainers. Refer to each upstream project for licenses, usage documentation, and updates.

**PentestBlueprint · The Dark Codex**
