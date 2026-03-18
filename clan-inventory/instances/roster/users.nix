{

  alex = {
    description = "Alex";
    uid = 3801;
    groups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "kvm"
      "dialout"
    ];
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVB44hBiASLPelTC//teEK3CpzrwswdBccLe9MKbaMp adecigear"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeeoL1jwVSachA9GdJxm/5TgCRBULfSDGLyP/nfmkMq alex@DESKTOP-SVRV9Q8"
    ];
    defaultPosition = "owner";
    defaultShell = "zsh";
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
    defaultPosition = "admin";
    defaultShell = "fish";
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5iZ0/HBn1HPJw/nMuJB9smTmhBkXdy4FiNVTXMtDqo github-ssh-key"
    ];
    defaultPosition = "admin";
    defaultShell = "fish";
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
    defaultPosition = "admin";
    defaultShell = "bash";
  };

  natalya = {
    description = "Natalya";
    uid = 3899;
    groups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "kvm"
    ];
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeeoL1jwVSachA9GdJxm/5TgCRBULfSDGLyP/nfmkMq alex@DESKTOP-SVRV9Q8"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVB44hBiASLPelTC//teEK3CpzrwswdBccLe9MKbaMp adecigear"
    ];
    defaultPosition = "basic";
    defaultShell = "bash";
  };

}
