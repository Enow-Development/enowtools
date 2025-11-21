# Roblox Manager - Cloudphone Edition

Script Termux untuk manage multiple clone aplikasi Roblox Lite di cloudphone dengan fitur lengkap.

## ✨ Features

- 🎮 **Interactive Menu** - User-friendly menu dengan pilihan angka (enowtools)
- 🔄 **Multi-Clone Management** - Buat dan manage multiple clone Roblox tanpa third-party apps
- 🍪 **Cookie Injection** - Auto-login dengan inject .ROBLOSECURITY cookies
- 🪟 **Freeform Mode** - Jalankan semua clone dalam multi-window freeform view
- 👁️ **Auto Monitoring** - Deteksi dan restart otomatis clone yang crash
- ⚡ **Cloudphone Optimized** - Ringan dan efisien untuk cloudphone environment
- 🔧 **Easy Maintenance** - Code clean dan modular untuk easy debugging

## 📋 Prerequisites

### Hardware/Platform
- ✅ Cloudphone atau Android device
- ✅ Minimum 2GB RAM (untuk multiple clones)
- ✅ Android 7.0+ (untuk freeform support)
- ✅ Storage cukup untuk multiple instances

### Software
- ✅ **Termux** - Terminal emulator untuk Android
- ✅ **ADB** - Android Debug Bridge (biasanya sudah ada di cloudphone)
- ✅ **Roblox Lite APK** - Custom/lite version dari Roblox

### Termux Packages
```bash
pkg update && pkg upgrade
pkg install bash jq git
```

### ADB Setup
```bash
# Enable ADB (jika belum)
settings put global adb_enabled 1

# Test ADB connection
adb devices
```

## 🚀 Installation

### 1. Clone Repository
```bash
cd ~
git clone <repository-url> roblox-manager
cd roblox-manager
```

### 2. Setup APK
Upload Roblox Lite APK ke device Anda, misalnya:
```bash
# Via ADB dari PC
adb push roblox-lite.apk /sdcard/Download/

# Atau download langsung di device
```

### 3. Konfigurasi
Edit [config/config.json](file:///h:/Roblox%20Manager/config/config.json):
```json
{
  "roblox_package": "com.roblox.client",
  "roblox_apk_path": "/sdcard/Download/roblox-lite.apk",
  "monitoring_interval": 30,
  "freeform_enabled": true,
  "auto_restart": true,
  "max_restart_attempts": 3,
  "log_level": "info"
}
```

**Note:** Package name biasanya tetap `com.roblox.client` meskipun menggunakan APK lite/custom. Hanya ubah jika APK Anda menggunakan package name yang berbeda.

### 4. Inisialisasi
```bash
./roblox-manager.sh init
./roblox-manager.sh clone 4
```

Dengan custom name:
```bash
./roblox-manager.sh clone 3 "MyRoblox"
# Akan create: MyRoblox_0, MyRoblox_1, MyRoblox_2
```

### Manage Clones

List semua clones:
```bash
./roblox-manager.sh list
```

Start specific clone:
```bash
./roblox-manager.sh start roblox_0
```

Stop specific clone:
```bash
./roblox-manager.sh stop roblox_0
```

Delete clone:
```bash
./roblox-manager.sh delete roblox_0
```

### Cookie Injection

Set dan inject cookie untuk auto-login:

```bash
# Interactive: akan prompt untuk paste cookie
./roblox-manager.sh inject roblox_0

# Atau save cookie dulu tanpa inject
./roblox-manager.sh set-cookie roblox_0

# Inject semua saved cookies sekaligus
./roblox-manager.sh inject-all
```

**Cara dapat cookie:**
1. Login ke roblox.com di browser
2. Buka Developer Tools (F12)
3. Pergi ke Application/Storage > Cookies
4. Copy value dari `.ROBLOSECURITY`
5. Paste saat diminta oleh script

### Freeform Mode

Enable freeform:
```bash
./roblox-manager.sh freeform enable
```

Launch instances dalam freeform:
```bash
# Launch specific instances
./roblox-manager.sh launch roblox_0 roblox_1 roblox_2

# Launch semua instances
./roblox-manager.sh launch-all
```

Rearrange windows (jika berantakan):
```bash
./roblox-manager.sh rearrange
```

Check freeform status:
```bash
./roblox-manager.sh freeform status
```

### Monitoring & Auto-Restart

Start monitoring daemon:
```bash
./roblox-manager.sh monitor start
```

Monitor akan:
- Check setiap 30 detik (configurable)
- Detect crashed/closed apps
- Auto-restart dengan freeform restoration
- Log semua activity

Check monitor status:
```bash
./roblox-manager.sh monitor status
```

View logs:
```bash
./roblox-manager.sh monitor logs 50
```

Stop monitoring:
```bash
./roblox-manager.sh monitor stop
```

### Update APK

Update semua clones dengan APK baru:
```bash
# Upload APK baru ke device
adb push roblox-lite-v2.apk /sdcard/Download/roblox-lite-v2.apk

# Update semua clones
./roblox-manager.sh update /sdcard/Download/roblox-lite-v2.apk
```

Data apps akan tetap preserved!

### Configuration

Get config value:
```bash
./roblox-manager.sh config get monitoring_interval
```

Set config value:
```bash
./roblox-manager.sh config set monitoring_interval 60
```

## 🔄 Complete Workflow Example

Setup lengkap dari awal:

```bash
# 1. Init
./roblox-manager.sh init

# 2. Create 4 clones
./roblox-manager.sh clone 4

# 3. Set cookies untuk setiap clone
./roblox-manager.sh set-cookie roblox_0
./roblox-manager.sh set-cookie roblox_1
./roblox-manager.sh set-cookie roblox_2
./roblox-manager.sh set-cookie roblox_3

# 4. Inject semua cookies
./roblox-manager.sh inject-all

# 5. Enable freeform
./roblox-manager.sh freeform enable

# 6. Launch all dalam freeform
./roblox-manager.sh launch-all

# 7. Start monitoring
./roblox-manager.sh monitor start

# 8. Check status
./roblox-manager.sh list
./roblox-manager.sh monitor status
```

Done! Sekarang Anda punya 4 Roblox instances running dengan auto-monitoring.

## 🗂️ Project Structure

```
roblox-manager/
├── roblox-manager.sh          # Main CLI
├── config/
│   ├── config.json            # Global configuration
│   └── accounts.json          # Instances & cookies
├── lib/
│   ├── utils.sh              # Core utilities
│   ├── clone-manager.sh      # Clone management
│   ├── cookie-injector.sh    # Cookie injection
│   ├── freeform-manager.sh   # Freeform management
│   └── monitor.sh            # Monitoring daemon
├── logs/
│   ├── roblox-manager.log    # Main log
│   └── monitor.log           # Monitor log
└── README.md
```

## 🛠️ Troubleshooting

### ADB Not Connected
```bash
# Enable ADB
settings put global adb_enabled 1

# Restart ADB server
adb kill-server
adb start-server

# Check devices
adb devices
```

### Cookie Injection Failed
1. Pastikan app sudah dijalankan minimal 1x (untuk create data directory)
2. Check cookie format valid (harus dimulai dengan `_|WARNING:-DO-NOT-SHARE`)
3. Try manual login jika injection gagal terus

### Freeform Not Working
```bash
# Check support
./roblox-manager.sh freeform status

# Force enable
settings put global enable_freeform_support 1
settings put global force_resizable_activities 1

# Restart device jika masih tidak work
```

### App Crashes Repeatedly
```bash
# Check logs
./roblox-manager.sh monitor logs 100

# Increase restart delay
./roblox-manager.sh config set restart_delay 10

# Reduce max restart attempts (avoid crash loop)
./roblox-manager.sh config set max_restart_attempts 2
```

### Clone Creation Failed
```bash
# Check APK path benar
./roblox-manager.sh config get roblox_apk_path

# Verify APK ada di device
adb shell "ls -l /sdcard/Download/roblox-lite.apk"

# Check package name match
./roblox-manager.sh config get roblox_package
```

### Permission Denied
```bash
# Make scripts executable
chmod +x roblox-manager.sh
chmod +x lib/*.sh
```

## ⚙️ Configuration Options

File: `config/config.json`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `roblox_package` | string | com.roblox.client | Package name APK Roblox |
| `roblox_apk_path` | string | - | Path APK di device |
| `monitoring_interval` | number | 30 | Check interval (detik) |
| `freeform_enabled` | boolean | true | Enable freeform mode |
| `freeform_layout` | string | grid | Layout mode (grid only) |
| `auto_restart` | boolean | true | Auto-restart crashed apps |
| `max_restart_attempts` | number | 3 | Max restart sebelum give up |
| `restart_delay` | number | 5 | Delay sebelum restart (detik) |
| `log_level` | string | info | Log level (debug/info/warn/error) |
| `cloudphone_mode` | boolean | true | Cloudphone optimizations |

## 📝 Notes

### Tentang Android Multi-User
Script ini menggunakan **native Android multi-user** feature:
- Setiap clone adalah Android user terpisah (ID 10, 11, 12, dst)
- Data completely isolated antar clones
- Tidak perlu third-party app
- Lightweight dan native

### Tentang Cookies
Cookie `.ROBLOSECURITY` adalah authentication token Roblox:
- **JANGAN SHARE** cookie Anda ke siapapun
- Cookie bisa expired, perlu re-inject
- Stored dalam `config/accounts.json` (keep this file secure!)

### Cloudphone Specific
Script ini optimized untuk cloudphone:
- Low resource monitoring
- ADB-based operations (no root needed)
- Manual APK management (no Play Store)
- Efficient freeform positioning

## 🐛 Known Issues

1. **Freeform tidak smooth di beberapa ROM** - Normal, tergantung ROM support
2. **Cookie injection kadang perlu 2x attempt** - Try lagi jika pertama gagal
3. **Monitor restart kadang lambat** - Increase `monitoring_interval` jika terlalu aggressive

## 💡 Tips & Best Practices

1. **Start small** - Test dengan 2-3 clones dulu sebelum create banyak
2. **Monitor logs** - Regular check `monitor logs` untuk detect issues early
3. **Backup config** - Copy `config/accounts.json` as backup
4. **Restart delay** - Set `restart_delay` lebih tinggi jika clone sering crash
5. **Freeform layout** - Adjust window count berdasarkan screen resolution

## 📄 License

MIT License - Feel free to modify and distribute

## 🤝 Contributing

Contributions welcome! Please:
1. Test changes di cloudphone environment
2. Keep code clean dan well-commented
3. Update documentation
4. Follow existing code style

## 📞 Support

Jika ada issues atau questions:
1. Check Troubleshooting section
2. Check logs: `./roblox-manager.sh monitor logs`
3. Verify configuration: `./roblox-manager.sh init`

---

**Built with ❤️ for Cloudphone Users**
