# 10: Pipeline rilis ala Status Saver

**What to build:** Replika workflow rilis Status Saver: `build-apk.yml`
(semantic-release tiap push ke main, split-per-abi, APK ditandatangani keystore
permanen, hard-fail bila SHA-256 signer tidak cocok), `.releaserc.js`, dan
`scripts/build-release.sh` yang diadaptasi untuk DuitQu. Keystore permanen baru
khusus aplikasi ini (di luar git).

**Blocked by:** 01 (butuh proyek Flutter).

**Status:** ready-for-agent

- [ ] Workflow + releaserc + build script ada dan lolos dry-run
- [ ] Build script hard-fail bila APK tidak memakai keystore permanen
- [ ] Dokumentasi setup secrets (KEYSTORE_BASE64/PASSWORD) — pengguna clear
      Confirm-access via browser takeover (pola Status Saver)
- [ ] Catatan: butuh repo GitHub `chulit/duitqu` + secrets terpasang agar rilis
      pertama jalan
