# Public L4 listeners. Each entry is one public socket on an edge machine
# forwarded to one Tailnet upstream. DNS stays explicit in Cloudflare resources.
{
  conduit = [
    {
      name = "forgejo-ssh";
      description = "Forgejo Git SSH";
      protocol = "tcp";
      listen = 2222;
      upstream = "sequoia.cymric-daggertooth.ts.net:2222";
    }

    {
      name = "minecraft-rlc";
      description = "Minecraft rats rlc";
      protocol = "tcp";
      listen = 25565;
      upstream = "leviathan.cymric-daggertooth.ts.net:25565";
    }
    {
      name = "minecraft-rlc-voice";
      description = "Minecraft rats rlc voice";
      protocol = "udp";
      listen = 24454;
      upstream = "leviathan.cymric-daggertooth.ts.net:24454";
    }

    {
      name = "minecraft-rats";
      description = "Minecraft rats";
      protocol = "tcp";
      listen = 25566;
      upstream = "leviathan.cymric-daggertooth.ts.net:25566";
    }
    {
      name = "minecraft-rats-voice";
      description = "Minecraft rats voice";
      protocol = "udp";
      listen = 24455;
      upstream = "leviathan.cymric-daggertooth.ts.net:24455";
    }

    {
      name = "minecraft-dj2";
      description = "Minecraft bros dj2";
      protocol = "tcp";
      listen = 25568;
      upstream = "leviathan.cymric-daggertooth.ts.net:25568";
    }
    {
      name = "minecraft-dj2-voice";
      description = "Minecraft bros dj2 voice";
      protocol = "udp";
      listen = 24457;
      upstream = "leviathan.cymric-daggertooth.ts.net:24457";
    }

    {
      name = "minecraft-hunter";
      description = "Minecraft hunter server";
      protocol = "tcp";
      listen = 25567;
      upstream = "lazarus.tail0e36b8.ts.net:25565";
    }

    {
      name = "minecraft-usf";
      description = "Minecraft usf";
      protocol = "tcp";
      listen = 25569;
      upstream = "leviathan.cymric-daggertooth.ts.net:25569";
    }
    {
      name = "minecraft-usf-voice";
      description = "Minecraft usf voice";
      protocol = "udp";
      listen = 24458;
      upstream = "leviathan.cymric-daggertooth.ts.net:24458";
    }

    {
      name = "minecraft-jav";
      description = "Minecraft jav";
      protocol = "tcp";
      listen = 25570;
      upstream = "leviathan.cymric-daggertooth.ts.net:25570";
    }
    {
      name = "minecraft-jav-voice";
      description = "Minecraft jav voice";
      protocol = "udp";
      listen = 24459;
      upstream = "leviathan.cymric-daggertooth.ts.net:24459";
    }

    {
      name = "palworld";
      description = "Palworld adeci";
      protocol = "udp";
      listen = 8211;
      upstream = "leviathan.cymric-daggertooth.ts.net:8211";
    }
    {
      name = "palworld-query";
      description = "Palworld adeci query";
      protocol = "udp";
      listen = 27015;
      upstream = "leviathan.cymric-daggertooth.ts.net:27015";
    }
  ];
}
