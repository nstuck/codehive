# Connecting clients

Nothing more needs to change on the server. Any client signed in to the same claude.ai account sees the same servers.

**iPhone.** Install the Claude app, sign in, and tap **Code** to open the session list.

**Browser.** On any computer, go to https://claude.ai/code and sign in. Your server's projects show up in the session list with a computer icon.

**Claude Desktop.** Install the Claude Desktop app on your workstation, sign in, and open the **Code** tab. Pick your server's projects from the session list.

Claude Desktop can also run Claude Code sessions on the workstation itself. To keep sessions running on the server, always open a server project from the session list. Don't start a new session in a folder on your workstation, because that session would run locally.

**Trusted Devices.** If you turn on Trusted Devices (see [Optional hardening](security.md#optional-hardening)), each phone, browser, and Desktop app has to be enrolled the first time it opens a Remote Control session. After that, an occasional Face ID, Touch ID, Windows Hello, or passkey check keeps it trusted.

## Push notifications (optional)

To get a notification when Claude needs your approval or finishes a long task:

1. Allow notifications for the Claude app on your iPhone.
2. In any Claude Code session, run `/config` and turn on **Push when actions required**, **Push when Claude decides**, or both.
