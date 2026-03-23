{
  trusted-caches = {
    module = {
      name = "@adeci/trusted-caches";
      input = "self";
    };
    roles.default = {
      tags = [ "adeci-net" ];
      settings.caches = [
        {
          url = "https://cache.numtide.com";
          publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
        }
        {
          url = "https://nix-community.cachix.org";
          publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
        }
        {
          url = "https://cache.clan.lol";
          publicKey = "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28=";
        }
      ];
    };
  };
}
