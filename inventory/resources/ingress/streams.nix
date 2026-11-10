{
  conduit = [
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
      name = "minecraft-gab";
      description = "Minecraft bros gab";
      protocol = "tcp";
      listen = 25573;
      upstream = "leviathan.cymric-daggertooth.ts.net:25573";
    }
    {
      name = "minecraft-gab-voice";
      description = "Minecraft bros gab voice";
      protocol = "udp";
      listen = 24460;
      upstream = "leviathan.cymric-daggertooth.ts.net:24460";
    }
  ];
}
