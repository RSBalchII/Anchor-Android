# 🤖 Anchor Engine Android Binary - Complete Build Plan

**Goal:** Create a one-command installable Anchor Engine MCP server for Termux/Android

---

## 📦 **What We're Building**

A standalone binary that:
1. ✅ Bundles Node.js runtime
2. ✅ Includes all native modules precompiled for arm64-android
3. ✅ Starts MCP server automatically
4. ✅ Connects to Qwen Code out of the box

**End User Experience:**
```bash
curl -L https://anchor-engine.io/install-android.sh | sh
```

---

## 🏗️ **Architecture**

```
Qwen Code (MCP Client)
         ↓ stdio
anchor-mcp (Standalone Binary)
  ↓ Node.js + pkg
  ↓ MCP Server
         ↓ HTTP localhost:3161
Anchor Engine Core + PGlite
```

---

## 📋 **Build Steps**

### **Phase 1: Fix GitHub Authentication** 🔴 (BLOCKER)

**Solution: SSH Keys for Termux**
```bash
ssh-keygen -t ed25519 -C "robert@termux"
# Add to GitHub: https://github.com/settings/keys
git remote set-url origin git@github.com:RSBalchII/anchor-engine-node.git
```

### **Phase 2: Build Native Modules** (2-4 hours)

Prebuild for arm64-android using GitHub Actions CI/CD.

### **Phase 3: Create MCP Binary** (1-2 hours)

```bash
cd mcp-server
pkg . --targets node20-android-arm64 --output anchor-mcp-android
```

**Output:** ~70MB standalone binary

### **Phase 4: Install Script** (1 hour)

```bash
#!/data/data/com.termux/files/usr/bin/bash
curl -L <release-url>/anchor-mcp-android -o ~/.anchor-engine/anchor-mcp
chmod +x ~/.anchor-engine/anchor-mcp
~/.anchor-engine/anchor-mcp &
```

### **Phase 5: GitHub Releases CI** (1-2 hours)

Automated builds on tag push.

---

## 📊 **Timeline**

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Fix GitHub Auth | 30 min | 🔴 Blocked |
| 2 | Build Native Modules | 2-4 hours | ⏳ |
| 3 | Create MCP Binary | 1-2 hours | ⏳ |
| 4 | Install Script | 1 hour | ⏳ |
| 5 | GitHub Releases CI | 1-2 hours | ⏳ |

**Total:** 6-10 hours

---

## 🧪 **Testing Checklist**

- [ ] Fresh Termux install
- [ ] Run install script
- [ ] Verify port 3161 listening
- [ ] Qwen Code auto-detects MCP
- [ ] Test anchor_query tool
- [ ] Verify data persists

---

## 📦 **Deliverables**

1. **GitHub Release** (v4.8.2-android)
   - `anchor-mcp-android` (70MB)
   - `anchor-engine-android` (80MB)
   - `install-android.sh`

2. **Documentation**
   - `ANDROID_INSTALL.md`
   - `ANDROID_BUILD.md`

---

**Created:** 2026-03-21  
**Target:** Android arm64 (Termux)
