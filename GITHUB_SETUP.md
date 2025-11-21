# 🚀 Setup GitHub - Step by Step Guide

## ✅ Step 1: Setup Git Config (WAJIB)

Jalankan command ini di PowerShell untuk set identitas Anda:

```powershell
# Set nama Anda
git config --global user.name "Nama Anda"

# Set email GitHub Anda
git config --global user.email "email@example.com"
```

**Contoh:**
```powershell
git config --global user.name "Enow"
git config --global user.email "enow@gmail.com"
```

---

## ✅ Step 2: Setup GitHub Authentication

Pilih salah satu metode:

### **Metode 1: GitHub CLI (RECOMMENDED - PALING MUDAH)**

```powershell
# Install GitHub CLI via winget
winget install --id GitHub.cli

# Login ke GitHub (akan buka browser)
gh auth login

# Pilih:
# - GitHub.com
# - HTTPS
# - Login via web browser
# - Paste token yang muncul
```

### **Metode 2: Personal Access Token (Manual)**

1. **Buat Token:**
   - Buka: https://github.com/settings/tokens
   - Klik "Generate new token" → "Classic"
   - Beri nama: `Roblox Manager`
   - Centang: `repo` (semua)
   - Klik "Generate token"
   - **COPY TOKEN** (tidak bisa dilihat lagi!)

2. **Setup Git Credential Manager:**
   ```powershell
   # Windows biasanya sudah ada Git Credential Manager
   # Saat push pertama kali, akan diminta username & token
   ```

### **Metode 3: SSH Key (Advanced)**

```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "email@example.com"

# Copy public key
Get-Content ~/.ssh/id_ed25519.pub | clip

# Tambahkan ke GitHub:
# https://github.com/settings/ssh/new
# Paste key yang sudah di-copy
```

---

## ✅ Step 3: Create GitHub Repository

**Lewat Web:**
1. Buka https://github.com/new
2. Repository name: `roblox-manager`
3. Description: `Multi-clone Roblox manager for cloudphone`
4. **JANGAN** centang "Initialize with README" (sudah ada)
5. Klik "Create repository"

**Lewat CLI (jika sudah install gh):**
```powershell
gh repo create roblox-manager --public --description "Multi-clone Roblox manager"
```

---

## ✅ Step 4: Connect & Push

Setelah repo GitHub dibuat, jalankan:

```powershell
cd "h:\Roblox Manager"

# Add all files
git add .

# Commit
git commit -m "Initial commit: Roblox Manager v1.0.0"

# Add remote (ganti USERNAME dengan username GitHub Anda)
git remote add origin https://github.com/USERNAME/roblox-manager.git

# Push
git branch -M main
git push -u origin main
```

**Contoh lengkap:**
```powershell
cd "h:\Roblox Manager"
git add .
git commit -m "Initial commit: Roblox Manager v1.0.0"
git remote add origin https://github.com/enow123/roblox-manager.git
git push -u origin main
```

---

## ✅ Step 5: Verify

Buka browser ke:
```
https://github.com/USERNAME/roblox-manager
```

Anda akan lihat semua file sudah ter-upload! 🎉

---

## 🔧 Troubleshooting

### Error: "Authentication failed"

**Jika pakai HTTPS:**
```powershell
# Install/update Git Credential Manager
winget install --id Git.Git

# Clear credential dan login ulang
git credential-manager-core erase https://github.com
```

Saat push lagi, akan muncul popup login GitHub.

### Error: "Permission denied (publickey)"

Pakai SSH tapi key belum ditambahkan:
```powershell
# Test SSH
ssh -T git@github.com

# Jika gagal, pakai HTTPS aja:
git remote set-url origin https://github.com/USERNAME/roblox-manager.git
```

### Error: "Repository not found"

Username atau repo name salah:
```powershell
# Check remote
git remote -v

# Update jika salah
git remote set-url origin https://github.com/USERNAME-YANG-BENAR/roblox-manager.git
```

---

## 📝 Next: Update Code

Setelah setup, untuk update code di masa depan:

```powershell
# Add changes
git add .

# Commit dengan message
git commit -m "Update: deskripsi perubahan"

# Push
git push
```

Mudah! 🚀

---

## 🎯 Quick Commands

```powershell
# Check status
git status

# View commit history
git log --oneline

# Create branch baru
git checkout -b feature-name

# View remote URL
git remote -v

# Clone repo (untuk transfer ke device lain)
git clone https://github.com/USERNAME/roblox-manager.git
```

---

**Ready untuk upload ke GitHub! Ikuti step-step di atas.** 🎉
