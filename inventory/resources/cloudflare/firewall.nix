# Cloudflare edge policy by hostname.
{
  hosts = {
    "vault.decio.us".customRules = [
      {
        # Admin: ssh -L 8222:localhost:8222 sequoia, then http://localhost:8222/admin
        description = "Vaultwarden: block the admin panel";
        action = "block";
        paths = [ "/admin" ];
      }
    ];
  };
}
