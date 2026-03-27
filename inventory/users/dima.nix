{
  description = "Dima";
  uid = 8070;
  shell = "bash";
  groups = [
    "wheel"
    "networkmanager"
    "video"
    "audio"
    "input"
    "kvm"
  ];
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5iZ0/HBn1HPJw/nMuJB9smTmhBkXdy4FiNVTXMtDqo github-ssh-key"
  ];
}
