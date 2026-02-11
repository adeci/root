see lassulus wrappers to understand more about these

but basically wrap the nix store bin for a package along with its config files, for a totally isolated wrapped dotfiles + packages setup = dotpkgs.

if you just cat the resulting entry in your profile/store for the package you'll see its really just a bash script that calls the main base bin for the program alongside its config setup however that program accepts config files (this is what the lassulus wrappers repo defines).
