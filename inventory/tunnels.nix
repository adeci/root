# Cloudflare tunnel definitions — single source of truth.
# Drives both terraform (tunnel + DNS creation) and NixOS (cloudflared).
# Machine names must match networking.hostName.
{
  sequoia = {
    "vault.decio.us" = "http://localhost:8222";
    "adeci.dev" = "http://localhost:4444";
    "matrix.decio.us" = "http://localhost:8448";
    "decio.us" = "http://localhost:8748";
  };

  leviathan = {
    "buildbot.decio.us" = "http://localhost:80";
  };
}
