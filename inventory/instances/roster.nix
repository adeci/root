{ inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};

  roster-users = {

    alex = {
      description = "Alex";
      uid = 3801;
      groups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeeoL1jwVSachA9GdJxm/5TgCRBULfSDGLyP/nfmkMq alex@DESKTOP-SVRV9Q8"
      ];
      defaultPosition = "owner";
      defaultShell = pkgs.fish;
      packages = [
        dotpkgs.git
        dotpkgs.starship
      ];
    };

    brittonr = {
      description = "Britton";
      uid = 1555;
      groups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
      ];
      defaultPosition = "owner";
      defaultShell = pkgs.fish;
      packages = [
        pkgs.git
        pkgs.starship
      ];
    };

    dima = {
      description = "Dima";
      uid = 8070;
      groups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP++JHcHDQfP5wcPxtb8o4liBWo+DFS13I4a9UgSTFec dima@nixos"
      ];
      defaultPosition = "owner";
      defaultShell = pkgs.fish;
      packages = [
        pkgs.git
        pkgs.starship
      ];
    };

    fmzakari = {
      description = "Farid";
      uid = 3802;
      groups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDruWlzuyOXV0Ltjv0vVoCSkf4/ic4ET4of6NTqLWfvw/wpNFDr3SXRDAftOFcyoKp0ls0z6xy3CH99pUNmVnU19nwPdPfY93FJHaVDmS3VUzhco+e+bd1Azds5bltg06H+2vuHFcFMA28Y1o5h6ISlVY45bUzhKnW6+9whwECGBQo5KSvSW0D50eP557DD1KZlWUuJrcno65iQUz6dZ+R5cwfoTRhCvh4ltzJ6Fel6RuHPzG3u56lHM+upsF1REljHsNGI6XF3bcRuIoSssvaT0ZzVJQz/YnI1+wGZDNSKJI7WE+xmhfhcGLDzVaxNkLuJLMv/goTcDsDBb1BVw0YF YubiKey #8531869 PIV Slot 9a"
      ];
      defaultPosition = "owner";
      defaultShell = pkgs.zsh;
      packages = [
        pkgs.git
        pkgs.starship
      ];
    };

  };

  roster-machines = {

    leviathan = {
      users = {
        alex = { };
        brittonr = { };
        dima = { };
        fmzakari = { };
      };
    };

    marine = {
      users = {
        alex = { };
      };
    };

    modus = {
      users = {
        alex = { };
      };
    };

    praxis = {
      users = {
        alex = { };
      };
    };

    spud = {
      users = {
        alex = { };
      };
    };

  };
in
{
  roster = {
    module = {
      name = "@onix/roster";
      input = "self";
    };
    roles.default = {
      tags.all = { };
      settings = {
        users = roster-users;
        machines = roster-machines;
      };
    };
  };
}
