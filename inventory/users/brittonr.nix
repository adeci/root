{
  description = "Britton";
  uid = 1555;
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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];
}
