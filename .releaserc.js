// semantic-release: version comes from conventional commits on main.
// No git/npm plugins: the version is never committed back — it lives in the
// git tag, and the APK receives it at build time (--build-name/--build-number).
module.exports = {
  branches: ["main"],
  plugins: [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@semantic-release/exec",
      {
        prepareCmd: "bash scripts/build-release.sh ${nextRelease.version}",
      },
    ],
    [
      "@semantic-release/github",
      {
        assets: [
          { path: "DuitQu-v*-arm64-v8a.apk", label: "DuitQu APK (arm64 — most phones)" },
          { path: "DuitQu-v*-armeabi-v7a.apk", label: "DuitQu APK (32-bit, older phones)" },
          { path: "DuitQu-v*-x86_64.apk", label: "DuitQu APK (x86_64, emulators)" },
        ],
      },
    ],
  ],
};
