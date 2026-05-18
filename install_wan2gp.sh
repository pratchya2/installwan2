#!/bin/bash
# สคริปต์ติดตั้ง Wan2GP อัตโนมัติสำหรับ Ubuntu (NVIDIA GPUs RTX 30XX - 50XX)
# ขีดสุดของความเร็วโดยใช้ PyTorch 2.10 และ CUDA 13.0 ตามคำแนะนำของทีมพัฒนา

set -e

echo "================================================="
echo "   🚀 เริ่มต้นกระบวนการติดตั้ง Wan2GP สำหรับ Ubuntu"
echo "================================================="

# 1. อัปเดตและติดตั้ง System Dependencies พื้นฐาน
echo -e "\n[1/6] กำลังอัปเดตระบบและติดตั้งแพ็กเกจพื้นฐาน..."
sudo apt update -y
sudo apt install -y git wget curl libgl1 libglib2.0-0 build-essential

# 2. ตรวจสอบและติดตั้ง Miniconda (ถ้ายังไม่มีในระบบ)
echo -e "\n[2/6] ตรวจสอบสภาพแวดล้อม Conda..."
if ! command -v conda &> /dev/null
then
    echo ">>> ไม่พบ Conda กำลังดาวน์โหลดและติดตั้ง Miniconda..."
    wget [https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh](https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh) -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda3
    rm miniconda.sh
    # กำหนด Path ชั่วคราวสำหรับรันสคริปต์
    export PATH="$HOME/miniconda3/bin:$PATH"
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    conda init
else
    echo ">>> ตรวจพบ Conda ในระบบแล้ว"
    eval "$(conda shell.bash hook)"
fi

# 3. โคลน Repository Wan2GP จาก GitHub
echo -e "\n[3/6] กำลังดาวน์โหลด Wan2GP Source Code..."
if [ ! -d "Wan2GP" ]; then
    git clone [https://github.com/deepbeepmeep/Wan2GP.git](https://github.com/deepbeepmeep/Wan2GP.git)
else
    echo ">>> โฟลเดอร์ Wan2GP มีอยู่แล้ว กำลังอัปเดตเป็นเวอร์ชันล่าสุด..."
    cd Wan2GP
    git pull
    cd ..
fi

cd Wan2GP

# 4. สร้างและเปิดใช้งาน Conda Environment
echo -e "\n[4/6] กำลังสร้าง Conda Environment ชื่อ 'wan2gp' (Python 3.11.14)..."
conda create -y -n wan2gp python=3.11.14
conda activate wan2gp

# 5. ติดตั้ง PyTorch รุ่นล่าสุด (Torch 2.10 + CUDA 13.0)
echo -e "\n[5/6] กำลังติดตั้ง PyTorch และระบบประมวลผล CUDA..."
pip install torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 --index-url [https://download.pytorch.org/whl/cu130](https://download.pytorch.org/whl/cu130)

# 6. ติดตั้ง Requirements หลัก และไลบรารีเร่งความเร็ว
echo -e "\n[6/6] กำลังติดตั้ง Dependencies จาก requirements.txt..."
pip install -r requirements.txt

# (Optional) ติดตั้ง Flash Attention ของ Linux เพื่อเพิ่มความเร็วในการ Generate
echo ">>> กำลังพยายามติดตั้ง Flash Attention (อาจใช้เวลาคอมไพล์สักครู่)..."
pip install flash-attn==2.7.2.post1 || echo "⚠️ คำเตือน: ติดตั้ง Flash Attention ไม่สำเร็จ แต่คุณยังสามารถใช้งาน Wan2GP ในโหมดปกติได้"

echo "================================================="
echo "   🎉 การติดตั้ง Wan2GP เสร็จสมบูรณ์แล้ว!"
echo "================================================="
echo ""
echo "📌 วิธีการเรียกใช้งานโปรแกรมในครั้งต่อไป:"
echo "1. รีสตาร์ท Terminal หรือรันคำสั่ง: source ~/.bashrc"
echo "2. เปิดใช้งาน Environment:      conda activate wan2gp"
echo "3. เข้าสู่โฟลเดอร์:              cd Wan2GP"
echo "4. สั่งรัน WebUI:              python wgp.py (หรือตามสคริปต์รันของโปรเจกต์)"
echo ""