#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Kubernetes Abstraction Benchmarking - Setup Script"
echo "======================================================="

# 1. Check for core system dependencies
echo "--> Checking for core dependencies..."
for cmd in docker node npm; do
  if ! command -v $cmd &> /dev/null; then
    echo "[ERROR] $cmd is not installed. Please install $cmd manually before running this script."
    exit 1
  fi
done

# Arch Linux specific check: Arch does not ship with GNU time by default, only the bash builtin
if [ ! -f "/usr/bin/time" ]; then
  echo "[ERROR] GNU 'time' is not installed at /usr/bin/time."
  echo "On Arch Linux, please install it by running: sudo pacman -S time"
  echo "This is required to measure RAM overhead."
  exit 1
fi
echo "Core dependencies (Docker, Node, NPM, GNU time) found."

# 2. Install kubectl
if ! command -v kubectl &> /dev/null; then
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
  if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$OS/$ARCH/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "--> kubectl is already installed."
fi

# 3. Install Kind (Kubernetes IN Docker)
if ! command -v kind &> /dev/null; then
  echo "--> Installing Kind..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
  if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.22.0/kind-$OS-$ARCH"
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  echo "--> Kind is already installed."
fi

# 4. Install Helm
if ! command -v helm &> /dev/null; then
  echo "--> Installing Helm..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash get_helm.sh
  rm get_helm.sh
else
  echo "--> Helm is already installed."
fi

# 5. Install Kustomize
if ! command -v kustomize &> /dev/null; then
  echo "--> Installing Kustomize..."
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/
else
  echo "--> Kustomize is already installed."
fi

# 6. Install Timoni
if ! command -v timoni &> /dev/null; then
  echo "--> Installing Timoni..."
  curl -sS https://timoni.sh/install.sh | sudo bash
else
  echo "--> Timoni is already installed."
fi

# 7. Install cdk8s-cli
if ! command -v cdk8s &> /dev/null; then
  echo "--> Installing cdk8s-cli globally..."
  sudo npm install -g cdk8s-cli
else
  echo "--> cdk8s-cli is already installed."
fi

# 8. Initialize Local CDK8s Dependencies
echo "--> Initializing local CDK8s project dependencies..."
cd "$(dirname "$0")/cdk8s_tool"
npm install
cd ..

# 9. Ensure Execution Permissions for all scripts
echo "--> Setting execution permissions for bash scripts..."
chmod +x install-dependencies.sh || true
chmod +x runner/run-all.sh
chmod +x helm_tool/apply.sh
chmod +x kustomize_tool/apply.sh
chmod +x timoni_tool/apply.sh
chmod +x cdk8s_tool/apply.sh

echo ""
echo "======================================================="
echo " Setup Complete! "
echo "======================================================="
echo "You can now run the benchmark orchestrator:"
echo "  1. Start the cluster:   kind create cluster --name thesis"
echo "  2. Run the benchmarks:  ./runner/run-all.sh"
