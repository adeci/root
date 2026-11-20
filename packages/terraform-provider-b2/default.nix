{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:
let
  version = "0.14.1";

  # The release's builds and their SHA256SUMS entries, by system.
  builds = {
    x86_64-linux = {
      platform = "linux_amd64";
      hash = "sha256-m7621a3f8s+WANCDYuvlKdCrjO2EwpXHuUcmJ06aynM=";
    };
    aarch64-linux = {
      platform = "linux_arm64";
      hash = "sha256-rd3dkL9lD1HmV08LZSM9YxokV3jd0d/amh88XJ7FogY=";
    };
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-r1gO2nEvFEa8jeE3GnpstIYO86LA72cOZR88ez/Uwwg=";
    };
  };
  build = builds.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "terraform-provider-b2";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Backblaze/terraform-provider-b2/releases/download/v${version}/terraform-provider-b2_${version}_${build.platform}.zip";
    inherit (build) hash;
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";

  # Same bytes as the registry serves.
  dontFixup = true;

  # The layout of nixpkgs' terraform-providers, which opentofu.withPlugins reads.
  installPhase = ''
    install -Dm755 terraform-provider-b2_${version} \
      $out/libexec/terraform-providers/registry.terraform.io/backblaze/b2/${version}/${build.platform}/terraform-provider-b2_${version}
  '';

  passthru.provider-source-address = "registry.terraform.io/backblaze/b2";

  meta = {
    platforms = lib.attrNames builds;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
