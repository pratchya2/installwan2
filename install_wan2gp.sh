#!/bin/bash

# ==============================================================================
# Wan2GP Setup Script for Ubuntu 24.04 (RTX 5090 / Salad.com)
# Optimized for Blackwell Architecture (PyTorch 2.10 + CUDA 13.0 + Python 3.11)
# ==============================================================================

set -e # หยุดการทำงานทันทีหากมี Error เกิดขึ้น

echo "🚀 Starting Wan2GP installation for RTX 5090..."

# 1. อัปเดตระบบและติดตั้ง Dependencies พื้นฐาน (รวมถึง FFmpeg สำหรับประมวลผลวิดีโอ)
echo "📦 Installing system dependencies (ffmpeg, git, curl, wget, etc.)..."
sudo apt update && sudo apt install -y git curl wget build-essential ffmpeg libsm6 libxext6 libgl1

# 2. ติดตั้ง Miniconda (ข้ามขั้นตอนนี้หากระบบมี Conda อยู่แล้ว)
if ! command -v conda &> /dev/null; then
    echo "🐍 Miniconda not found. Installing Miniconda..."
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    source ~/miniconda3/bin/activate
    conda init --all
else
    echo "✅ Miniconda is already installed."
    source $(conda info --base)/etc/profile.d/conda.sh
fi

# 3. โคลน Repository ของ Wan2GP
if [ ! -d "Wan2GP" ]; then
    echo "📥 Cloning deepbeepmeep/Wan2GP repository..."
    git clone https://github.com/deepbeepmeep/Wan2GP.git
else
    echo "⚠️ Wan2GP directory already exists. Pulling latest changes..."
    cd Wan2GP
    git pull
    cd ..
fi

cd Wan2GP

# 4. สร้างและเปิดใช้งาน Conda Environment (ใช้ Python 3.11.14 ตาม Official Recommendation)
echo "🌐 Creating Conda environment 'wan2gp' with Python 3.11.14..."
conda create -y -n wan2gp python=3.11.14
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wan2gp

# 5. ติดตั้ง PyTorch 2.10 สำหรับ CUDA 13.0 (เหมาะที่สุดสำหรับ RTX 50XX)
echo "🔥 Installing PyTorch 2.10 (CUDA 13.0)..."
pip install torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 --index-url https://download.pytorch.org/whl/cu130

# 6. ติดตั้ง Requirements ของโปรเจกต์
echo "📚 Installing Wan2GP Python requirements..."
pip install -r requirements.txt

echo "🎉 Installation Complete!"
echo "------------------------------------------------------"
echo "คำสั่งสำหรับเริ่มต้นใช้งาน Wan2GP ในครั้งถัดไป:"
echo "  conda activate wan2gp"
echo "  cd ~/Wan2GP"
echo "  python webui.py หรือรันสคริปต์เริ่มต้นของ Repo"
echo "------------------------------------------------------"
