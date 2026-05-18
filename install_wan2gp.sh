#!/bin/bash
# ============================================================
#  install_wan2gp.sh
#  ติดตั้ง Wan2GP บน Ubuntu 24.04 + RTX 5090 (Blackwell)
#  ใช้ Python 3.11.14 + PyTorch 2.10 + CUDA 13.0
# ============================================================

set -e  # หยุดทันทีถ้ามี error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Wan2GP Installer — RTX 5090 / Ubuntu 24  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ── 0. ตรวจสอบ GPU ─────────────────────────────────────────
info "ตรวจสอบ GPU..."
if ! command -v nvidia-smi &>/dev/null; then
    err "ไม่พบ nvidia-smi — กรุณาติดตั้ง NVIDIA driver ก่อน"
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""

# ── 1. อัปเดต package และติดตั้ง dependencies ────────────────
info "อัปเดต apt และติดตั้ง dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    git curl wget build-essential \
    libssl-dev zlib1g-dev libffi-dev \
    ffmpeg libsm6 libxext6 \
    python3-pip python3-dev

# ── 2. ติดตั้ง Miniconda (ถ้ายังไม่มี) ──────────────────────
CONDA_DIR="$HOME/miniconda3"
if [ ! -d "$CONDA_DIR" ]; then
    info "ดาวน์โหลดและติดตั้ง Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$CONDA_DIR"
    rm /tmp/miniconda.sh
    log "ติดตั้ง Miniconda เสร็จ"
else
    log "พบ Miniconda อยู่แล้วที่ $CONDA_DIR"
fi

# เปิดใช้งาน conda ใน shell นี้
export PATH="$CONDA_DIR/bin:$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"

# เพิ่ม conda init ใน .bashrc (ถ้ายังไม่มี)
if ! grep -q "conda initialize" ~/.bashrc 2>/dev/null; then
    conda init bash
    log "เพิ่ม conda init ลง ~/.bashrc แล้ว"
fi

# ── 3. ติดตั้ง CUDA 13.0 keyring (สำหรับ RTX 5090) ──────────
info "เพิ่ม CUDA 13.0 repository..."
CUDA_KEYRING="cuda-keyring_1.1-1_all.deb"
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/$CUDA_KEYRING -O /tmp/$CUDA_KEYRING
sudo dpkg -i /tmp/$CUDA_KEYRING
sudo apt-get update -qq
rm /tmp/$CUDA_KEYRING

info "ติดตั้ง CUDA Toolkit 13.0..."
sudo apt-get install -y -qq cuda-toolkit-13-0 || warn "CUDA 13.0 ติดตั้งไม่สำเร็จ — อาจต้องทำด้วยตนเอง: https://developer.nvidia.com/cuda-13-1-0-download-archive"

# ตั้งค่า PATH สำหรับ CUDA
CUDA_HOME=/usr/local/cuda
if [ -d /usr/local/cuda-13.0 ]; then
    CUDA_HOME=/usr/local/cuda-13.0
fi
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

# ── 4. สร้าง conda environment ──────────────────────────────
ENV_NAME="wan2gp"
if conda env list | grep -q "^$ENV_NAME "; then
    warn "พบ environment '$ENV_NAME' อยู่แล้ว — ข้ามการสร้าง"
else
    info "สร้าง conda environment '$ENV_NAME' (Python 3.11.14)..."
    conda create -n "$ENV_NAME" python=3.11.14 -y
    log "สร้าง environment เสร็จ"
fi

# Activate environment
conda activate "$ENV_NAME"
log "activate environment: $ENV_NAME"

# ── 5. Clone Wan2GP ─────────────────────────────────────────
INSTALL_DIR="$HOME/Wan2GP"
if [ -d "$INSTALL_DIR" ]; then
    warn "พบโฟลเดอร์ $INSTALL_DIR อยู่แล้ว — pull อัปเดตแทน"
    cd "$INSTALL_DIR"
    git fetch origin && git reset --hard origin/main
else
    info "Clone Wan2GP repository..."
    git clone https://github.com/deepbeepmeep/Wan2GP.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    log "Clone เสร็จ"
fi

# ── 6. ติดตั้ง PyTorch 2.10 + CUDA 13.0 (RTX 5090 Blackwell) ─
info "ติดตั้ง PyTorch 2.10 + CUDA 13.0 (ใช้เวลานาน ~5 นาที)..."
pip install torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 \
    --index-url https://download.pytorch.org/whl/cu130 -q
log "ติดตั้ง PyTorch เสร็จ"

# ── 7. ติดตั้ง requirements ─────────────────────────────────
info "ติดตั้ง requirements.txt..."
pip install -r requirements.txt -q
log "ติดตั้ง requirements เสร็จ"

# ── 8. ติดตั้ง Triton ───────────────────────────────────────
info "ติดตั้ง Triton (สำหรับ Linux)..."
pip install triton -q
log "ติดตั้ง Triton เสร็จ"

# ── 9. ติดตั้ง SageAttention (compile จาก source) ────────────
info "ติดตั้ง SageAttention (compile — ใช้เวลา ~5-10 นาที)..."
pip install ninja wheel packaging -q
pip install --no-build-isolation git+https://github.com/thu-ml/SageAttention.git -q \
    && log "ติดตั้ง SageAttention เสร็จ" \
    || warn "SageAttention compile ไม่สำเร็จ — Wan2GP ยังใช้งานได้ แต่ช้ากว่า"

# ── 10. ติดตั้ง Flash Attention 2 ───────────────────────────
info "ติดตั้ง Flash Attention 2 (compile — ใช้เวลา ~10-15 นาที)..."
pip install flash-attn --no-build-isolation -q \
    && log "ติดตั้ง Flash Attention เสร็จ" \
    || warn "Flash Attention compile ไม่สำเร็จ — ข้ามได้ (optional)"

# ── 11. ทดสอบ PyTorch + GPU ─────────────────────────────────
info "ทดสอบ PyTorch + GPU..."
python - <<'PYEOF'
import torch
print(f"  PyTorch: {torch.__version__}")
print(f"  CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    print(f"  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
PYEOF

# ── 12. สร้าง launch script ──────────────────────────────────
cat > "$INSTALL_DIR/launch.sh" <<LAUNCH
#!/bin/bash
# Launch Wan2GP
export PATH="$CONDA_DIR/bin:\$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"
conda activate wan2gp
cd "$INSTALL_DIR"

# รัน Wan2GP พร้อม share link (เหมาะสำหรับ remote server)
# ปรับ port และ option ตามต้องการ
python wgp.py --server-name 0.0.0.0 --server-port 7860 "\$@"
LAUNCH
chmod +x "$INSTALL_DIR/launch.sh"

# ── 13. สรุปผล ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ติดตั้ง Wan2GP เสร็จสมบูรณ์! 🎉         ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  📂 ติดตั้งที่     : ${CYAN}$INSTALL_DIR${NC}"
echo -e "  🐍 Environment   : ${CYAN}conda activate wan2gp${NC}"
echo ""
echo -e "  🚀 วิธีเปิดใช้งาน:"
echo -e "     ${YELLOW}cd $INSTALL_DIR && bash launch.sh${NC}"
echo ""
echo -e "  หรือเปิดแบบ public URL:"
echo -e "     ${YELLOW}conda activate wan2gp && python wgp.py --share${NC}"
echo ""
echo -e "  🌐 เข้าใช้งาน : ${CYAN}http://YOUR_SERVER_IP:7860${NC}"
echo ""
warn "ถ้า conda ไม่รู้จักในครั้งถัดไป ให้รัน: source ~/.bashrc"
