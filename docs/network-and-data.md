# Network and data

Your clients and your server never connect directly. Both make outbound connections to Anthropic, and Anthropic passes messages between them.

```
   Clients (any network)                       Your server
   ┌─────────────────────┐                          │
   │ iPhone (Claude app) │                          │
   │ Browser             │                          │
   │ Claude Desktop      │                          │
   └──────────┬──────────┘                          │
              │  HTTPS / TLS            HTTPS / TLS │
              │  (outbound)              (outbound) │
              ▼                                     ▼
   ┌──────────────────────────────────────────────────────┐
   │                    Anthropic API                     │
   │  • routes messages between clients and server        │
   │  • stores the session transcript for sync/reconnect  │
   │  • runs the model                                    │
   └──────────────────────────────────────────────────────┘
```

**Connection direction.** Each Remote Control server registers with the Anthropic API and then waits for work over outbound HTTPS. When you open a session from any client, Anthropic routes messages between the client and that server over a streaming connection. Nothing ever connects in to your server.

## What this means for networking

- No inbound ports, port forwarding, reverse proxy, DNS record, or TLS certificate is needed for this.
- The server can sit behind NAT, a home router, or a firewall that blocks all inbound traffic.
- The server only needs outbound HTTPS (port 443) to Anthropic. A daily check for new codehive releases also goes to `api.github.com`, which you can turn off (see [Update notices](updating.md#update-notices)).
- Clients can be on any network, such as home Wi-Fi, an office network, or cellular, without a VPN.
- Things that intercept or redirect that outbound traffic can break Remote Control. That includes setting `ANTHROPIC_BASE_URL` to a gateway or proxy, and using Amazon Bedrock, Google Cloud's Agent Platform, or Microsoft Foundry.

**Encryption and credentials.** All traffic goes over TLS. The connection uses several short-lived credentials, each limited to one purpose and each expiring on its own schedule.

## Where your data lives

| Data | Location |
|---|---|
| Your files and code | Only on your server |
| Commands Claude runs | Only on your server |
| Conversation transcript and tool activity | Stored by Anthropic while Remote Control is connected, to keep devices in sync and support reconnects |
| Prompts and file contents Claude reads | Sent to Anthropic for the model to process, the same as any Claude Code session |
| Photos you attach in a client | Sent directly to Claude as part of your message |
| Other files you attach in a client | Downloaded to your server and passed to Claude as file references |
