#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[>]${NC} $1"; }
err()  { echo -e "${RED}[X]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Wan2GP Installer - RTX 5090/Ubuntu 24  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

info "Checking GPU..."
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""

info "Updating apt..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget build-essential libssl-dev zlib1g-dev libffi-dev ffmpeg libsm6 libxext6 python3-pip python3-dev

CONDA_DIR="$HOME/miniconda3"
if [ ! -d "$CONDA_DIR" ]; then
    info "Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$CONDA_DIR"
    rm /tmp/miniconda.sh
    log "Miniconda installed"
else
    log "Miniconda found"
fi

export PATH="$CONDA_DIR/bin:$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"

if ! grep -q "conda initialize" ~/.bashrc 2>/dev/null; then
    conda init bash
    log "Added conda to ~/.bashrc"
fi

info "Adding CUDA 13.0 repository..."
CUDA_KEYRING="cuda-keyring_1.1-1_all.deb"
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/$CUDA_KEYRING -O /tmp/$CUDA_KEYRING
sudo dpkg -i /tmp/$CUDA_KEYRING
sudo apt-get update -qq
rm /tmp/$CUDA_KEYRING

info "Installing CUDA Toolkit 13.0..."
sudo apt-get install -y -qq cuda-toolkit-13-0 || warn "CUDA install may need manual setup"

CUDA_HOME=/usr/local/cuda
if [ -d /usr/local/cuda-13.0 ]; then
    CUDA_HOME=/usr/local/cuda-13.0
fi
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

ENV_NAME="wan2gp"
if conda env list | grep -q "^$ENV_NAME "; then
    warn "Environment '$ENV_NAME' exists - skipping creation"
else
    info "Creating conda environment (Python 3.11.14)..."
    conda create -n "$ENV_NAME" python=3.11.14 -y
    log "Environment created"
fi

conda activate "$ENV_NAME"
log "Activated environment: $ENV_NAME"

INSTALL_DIR="$HOME/Wan2GP"
if [ -d "$INSTALL_DIR" ]; then
    warn "Found existing Wan2GP - updating..."
    cd "$INSTALL_DIR"
    git fetch origin && git reset --hard origin/main
else
    info "Cloning Wan2GP..."
    git clone https://github.com/deepbeepmeep/Wan2GP.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    log "Clone complete"
fi

info "Installing PyTorch 2.10 + CUDA 13.0 (this takes ~5 min)..."
pip install torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 --index-url https://download.pytorch.org/whl/cu130 -q
log "PyTorch installed"

info "Installing requirements.txt..."
pip install -r requirements.txt -q
log "Requirements installed"

info "Installing Triton..."
pip install triton -q
log "Triton installed"

info "Installing SageAttention (this takes ~5-10 min)..."
pip install ninja wheel packaging -q
pip install --no-build-isolation git+https://github.com/thu-ml/SageAttention.git -q && log "SageAttention installed" || warn "SageAttention failed - optional"

info "Installing Flash Attention 2 (this takes ~10-15 min)..."
pip install flash-attn --no-build-isolation -q && log "Flash Attention installed" || warn "Flash Attention failed - optional"

info "Testing PyTorch + GPU..."
python - <<'PYEOF'
import torch
print(f"  PyTorch: {torch.__version__}")
print(f"  CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    print(f"  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
PYEOF

cat > "$INSTALL_DIR/launch.sh" <<LAUNCH
#!/bin/bash
export PATH="$CONDA_DIR/bin:\$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"
conda activate wan2gp
cd "$INSTALL_DIR"
python wgp.py --server-name 0.0.0.0 --server-port 7860 "\$@"
LAUNCH
chmod +x "$INSTALL_DIR/launch.sh"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Wan2GP installation complete!         ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Location    : ${CYAN}$INSTALL_DIR${NC}"
echo -e "  Environment : ${CYAN}conda activate wan2gp${NC}"
echo ""
echo -e "  Start with:"
echo -e "     ${YELLOW}cd $INSTALL_DIR && bash launch.sh${NC}"
echo ""
echo -e "  Or use --share for public link:"
echo -e "     ${YELLOW}python wgp.py --share${NC}"
echo ""
echo -e "  Access at: ${CYAN}http://YOUR_SERVER_IP:7860${NC}"
echo ""
