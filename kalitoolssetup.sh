#!/usr/bin/env bash
# Kali fresh-install toolkit. Run as your normal user (not root).
set -Eeuo pipefail
umask 022
if [[ $EUID -eq 0 ]]; then echo 'Run as a normal user, not root.' >&2; exit 1; fi
if ! command -v apt-get >/dev/null || ! grep -qi kali /etc/os-release; then echo 'This script targets Kali Linux.' >&2; exit 1; fi
TOOLS="$HOME/Tools"
LOGDIR="$TOOLS/logs"
mkdir -p "$LOGDIR" "$TOOLS"/{windows,pivoting,web,ad,source,bloodhound}
LOG="$LOGDIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
FAILED=()
step() { echo -e "\n==== $* ===="; }
try() { local name="$1"; shift; step "$name"; if "$@"; then echo "[OK] $name"; else echo "[FAILED] $name"; FAILED+=("$name"); fi; }
fetch() { local url="$1" dest="$2"; if [[ -s "$dest" ]]; then echo "Already exists: $dest"; return 0; fi; curl -fL --retry 3 --connect-timeout 20 -o "$dest.part" "$url" && mv "$dest.part" "$dest"; }
clone() { local url="$1" dest="$2"; if [[ -d "$dest/.git" ]]; then echo "Already cloned: $dest"; else git clone --depth 1 "$url" "$dest"; fi; }
pipx_git() { local name="$1" url="$2"; if pipx list --short 2>/dev/null | grep -Eq "^${name}([[:space:]]|$)"; then echo "pipx app already installed: $name"; else pipx install "$url"; fi; }
export DEBIAN_FRONTEND=noninteractive
step 'APT update and baseline tools'
sudo -v
sudo apt-get update
# APT-managed tools follow Kali packaging; avoid system pip modifications.
BASE=(git curl wget unzip tar jq pipx python3 python3-venv python3-dev build-essential libssl-dev libffi-dev libkrb5-dev ca-certificates gnupg nmap rustscan netexec impacket-scripts python3-impacket certipy-ad bloodhound.py neo4j terminator docker.io docker-compose-plugin smbclient ldap-utils dnsutils enum4linux-ng evil-winrm hashcat john responder seclists gobuster ffuf sqlmap feroxbuster rlwrap plocate)
for pkg in "${BASE[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    if ! sudo apt-get install -y "$pkg"; then FAILED+=("apt:$pkg"); fi
  else echo "[SKIP] Package unavailable: $pkg"; fi
done
try 'Update locate database' sudo updatedb
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
try 'Ensure pipx PATH' pipx ensurepath
# NetExec: official Kali-specific wiki method is apt install netexec.
# Impacket: Kali's packaged scripts avoid --break-system-packages.

step 'BloodHound Community Edition CLI (download only; containers are opt-in)'
ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" == amd64 || "$ARCH" == arm64 ]]; then
  BH_DIR="$TOOLS/bloodhound"
  if try 'Download BloodHound CLI' fetch "https://github.com/SpecterOps/bloodhound-cli/releases/latest/download/bloodhound-cli-linux-${ARCH}.tar.gz" "$BH_DIR/bloodhound-cli-linux-${ARCH}.tar.gz"; then
    try 'Extract BloodHound CLI' tar -xzf "$BH_DIR/bloodhound-cli-linux-${ARCH}.tar.gz" -C "$BH_DIR"
    if [[ -f "$BH_DIR/bloodhound-cli" ]]; then chmod +x "$BH_DIR/bloodhound-cli"; ln -sfn "$BH_DIR/bloodhound-cli" "$HOME/.local/bin/bloodhound-cli"; fi
  fi
else echo "[SKIP] BloodHound CLI unsupported architecture: $ARCH"; fi

step 'Ligolo-ng 0.8.2 (Linux proxy + Windows agent)'
if [[ "$ARCH" == amd64 ]]; then
  PIV="$TOOLS/pivoting"
  if try 'Download Ligolo proxy' fetch 'https://github.com/nicocha30/ligolo-ng/releases/download/v0.8.2/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz' "$PIV/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz"; then
    mkdir -p "$PIV/ligolo-proxy"
    try 'Extract Ligolo proxy' tar -xzf "$PIV/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz" -C "$PIV/ligolo-proxy"
  fi
  if try 'Download Ligolo Windows agent' fetch 'https://github.com/nicocha30/ligolo-ng/releases/download/v0.8.2/ligolo-ng_agent_0.8.2_windows_amd64.zip' "$PIV/ligolo-ng_agent_0.8.2_windows_amd64.zip"; then
    mkdir -p "$PIV/ligolo-agent-windows"
    try 'Extract Ligolo Windows agent' unzip -oq "$PIV/ligolo-ng_agent_0.8.2_windows_amd64.zip" -d "$PIV/ligolo-agent-windows"
  fi
else echo '[SKIP] Pinned Ligolo artifacts target amd64'; fi

step 'AD helper repositories and isolated Python apps'
try 'Clone PKINITtools' clone 'https://github.com/dirkjanm/PKINITtools.git' "$TOOLS/source/PKINITtools"
try 'Clone pywhisker' clone 'https://github.com/ShutdownRepo/pywhisker.git' "$TOOLS/source/pywhisker"
try 'Clone targetedKerberoast' clone 'https://github.com/ShutdownRepo/targetedKerberoast.git' "$TOOLS/source/targetedKerberoast"
# Separate venvs, because these research tools may have conflicting requirements.
install_venv_repo() {
  local name="$1" dir="$2" script="$3" venv="$TOOLS/ad/.venvs/$name"
  [[ -d "$dir" ]] || return 1
  if [[ ! -x "$venv/bin/python" ]]; then python3 -m venv "$venv"; fi
  "$venv/bin/python" -m pip install --disable-pip-version-check -U pip
  if [[ -f "$dir/requirements.txt" ]]; then "$venv/bin/python" -m pip install -r "$dir/requirements.txt"; fi
  [[ -f "$dir/$script" ]] || return 1
  printf '#!/usr/bin/env bash\nexec %q %q "$@"\n' "$venv/bin/python" "$dir/$script" > "$HOME/.local/bin/$name"
  chmod +x "$HOME/.local/bin/$name"
}
try 'Set up pywhisker venv' install_venv_repo pywhisker "$TOOLS/source/pywhisker" pywhisker/pywhisker.py
try 'Set up targetedKerberoast venv' install_venv_repo targetedKerberoast "$TOOLS/source/targetedKerberoast" targetedKerberoast.py
# PKINITtools uses Impacket; install the dependency in its own environment.
setup_pkinit() {
  local dir="$TOOLS/source/PKINITtools" venv="$TOOLS/ad/.venvs/pkinit"
  [[ -d "$dir" ]] || return 1
  [[ -x "$venv/bin/python" ]] || python3 -m venv "$venv"
  "$venv/bin/python" -m pip install -U pip impacket minikerberos
  local s
  for s in gettgtpkinit.py getnthash.py gets4uticket.py; do
    [[ -f "$dir/$s" ]] || continue
    printf '#!/usr/bin/env bash\nexec %q %q "$@"\n' "$venv/bin/python" "$dir/$s" > "$HOME/.local/bin/$s"
    chmod +x "$HOME/.local/bin/$s"
  done
}
try 'Set up PKINITtools venv' setup_pkinit

step 'Reference files and Windows lab binaries'
try 'Download nc64.exe' fetch 'https://raw.githubusercontent.com/int0x33/nc.exe/master/nc64.exe' "$TOOLS/windows/nc64.exe"
try 'Download Rubeus.exe' fetch 'https://raw.githubusercontent.com/r3motecontrol/Ghostpack-CompiledBinaries/master/Rubeus.exe' "$TOOLS/windows/Rubeus.exe"
try 'Download mimikatz.exe' fetch 'https://raw.githubusercontent.com/ParrotSec/mimikatz/master/x64/mimikatz.exe' "$TOOLS/windows/mimikatz.exe"
try 'Download PHP reverse shell' fetch 'https://raw.githubusercontent.com/ivan-sincek/php-reverse-shell/master/src/reverse/php_reverse_shell.php' "$TOOLS/web/php_reverse_shell.php"

step 'Sublime Text official APT repository'
install_sublime() {
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL 'https://download.sublimetext.com/sublimehq-pub.gpg' | sudo tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
  printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' | sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null
  sudo apt-get update && sudo apt-get install -y sublime-text
}
try 'Install Sublime Text' install_sublime

step 'Verification'
for cmd in nxc rustscan nmap impacket-secretsdump certipy-ad bloodhound-cli docker terminator; do
  if command -v "$cmd" >/dev/null 2>&1; then echo "[FOUND] $cmd: $(command -v "$cmd")"; else echo "[CHECK] $cmd not on PATH (may use a different package command name)"; fi
done
cat <<EOM

Installation log: $LOG
Tools directory: $TOOLS
BloodHound CE is downloaded, not started. To initialize it, first ensure
Docker is running and Docker Compose v2 works, then run:
  bloodhound-cli install
You may need: sudo systemctl enable --now docker
After installation, follow the CLI output and save the initial credentials.
Open a NEW terminal to refresh PATH.
EOM
if ((${#FAILED[@]})); then printf '\nFailed steps (%d):\n' "${#FAILED[@]}"; printf ' - %s\n' "${FAILED[@]}"; exit 1; fi
echo 'All requested steps completed without reported errors.'
