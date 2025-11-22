let
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
      defaultShell = "fish";
    };

  };

  roster-machines = {

    modus = {
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
