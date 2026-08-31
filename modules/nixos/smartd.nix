{
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      systembus-notify.enable = true;
      wall.enable = false;
    };
  };
}
