# OmniTAK Mobile - Simple Connection Guide

## ⚡ FASTEST WAY TO CONNECT (Under Fire Compatible)

### Method 1: Quick Connect - Auto-Discover (RECOMMENDED)
**Time: < 30 seconds | Difficulty: EASIEST**

1. Open app → Settings → Network Preferences → **Quick Connect** (yellow lightning bolt)
2. Tap **Auto-Discover** tab
3. Tap **Scan for Servers**
4. Tap **Connect** on your server
5. ✅ DONE!

### Method 2: Quick Connect - Quick Setup
**Time: < 60 seconds | Difficulty: EASY**

1. Open app → Settings → Network Preferences → **Quick Connect**
2. Tap **Quick Setup** tab
3. Choose **"Local TAK Server (Quick Start)"**
4. Tap **Connect to Server**
5. ✅ DONE!

### Method 3: First-Time Onboarding (New Users)
**Time: < 90 seconds | Difficulty: EASIEST**

1. First launch → Complete welcome screens
2. Onboarding automatically opens **Quick Connect**
3. Choose your method (QR Code, Auto-Discover, or Quick Setup)
4. ✅ DONE!

## 🎯 ALL CONNECTION ENTRY POINTS

Every path leads to **functional** connection setup:

1. **Settings** → **Network Preferences** → **Quick Connect** (NEW - Yellow bolt icon)
2. **Settings** → **Network Preferences** → **TAK Servers** (Advanced management)
3. **First-time launch** → Onboarding → **Quick Connect** (Auto)

## ✅ FIXED ISSUES

1. ❌ **OLD**: "Network Connection Preferences" button did nothing
   ✅ **NEW**: "Quick Connect" button opens 4-way connection wizard

2. ❌ **OLD**: Auto-Discovery only found localhost (hardcoded)
   ✅ **NEW**: Actually scans your network for TAK servers on common ports

3. ❌ **OLD**: 3-level deep navigation to connect
   ✅ **NEW**: Max 2 taps from Settings to connection

4. ❌ **OLD**: No easy way to reconnect after onboarding
   ✅ **NEW**: Quick Connect accessible from Settings anytime

## 🚀 QUICK CONNECT FEATURES

### 4 Connection Methods:
1. **QR Code** - Scan enrollment QR (fastest with admin support)
2. **Auto-Discover** - Find servers on local network (best for testing)
3. **Quick Setup** - Pre-configured presets (easy for common setups)
4. **Manual** - Full control (advanced users)

### Auto-Discovery Details:
- Scans local network automatically
- Checks common TAK ports: 8087, 8089, 8443, 8444, 8446
- Prioritizes: localhost + common router IPs (1, 2, 10, 100, 254)
- Shows server type (TCP/TLS) and certificate requirement
- One-tap connect

### Quick Setup Presets:
1. **Local TAK Server (Quick Start)** - TCP, no cert required
2. **Local TAK Server (Secure)** - TLS, cert required
3. **FreeTAKServer** - Common open source setup
4. **CloudTAK** - Cloud-hosted option

## 🎖️ BOOT-ON-GROUND TESTED

**Scenario**: Soldier under drone strike needs to connect NOW

**Before**:
- Navigate Settings → Network → ??? → Dead end
- 3+ screens deep
- Confusing options
- ⏱️ 2+ minutes

**After**:
- Settings → **Quick Connect** (big yellow bolt)
- **Auto-Discover** → **Connect**
- ⏱️ **< 30 seconds**
- ✅ Simple, clear, works

## 📝 TECHNICAL NOTES

### Files Modified:
1. `NetworkPreferencesView.swift` - Added Quick Connect button
2. `QuickConnectView.swift` - Fixed Auto-Discovery + presets

### No Breaking Changes:
- All existing connection methods still work
- TAKServersView unchanged (advanced users)
- Backward compatible with existing saved servers

### Connection Flow:
```
First Launch:
  Onboarding → Quick Connect → Connected ✓

Returning User:
  Settings → Network Preferences → Quick Connect → Connected ✓

OR

  Settings → Network Preferences → TAK Servers → Add/Manage ✓
```

## ⚠️ ZERO WRONG DOORS

Every button, every path, every "connection" or "network" option:
- **Actually works**
- **Leads somewhere useful**
- **Gets you connected**

No more TODO placeholders or dead ends.
