{ stdenv, lib, fetchFromGitHub, kernel, kmod }:

stdenv.mkDerivation rec {
  pname = "mbp2016-touchbar";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "Heratiki";
    repo = "macbook12-spi-driver";
    rev = "1d5cd6f82c2f9ee6e2431ac51237c2a82c397b77";
    hash = "sha256-hkPfoX1PLNCNu2YoxbX7vvbOP6nwDXL8QyusYMaitf0=";
  };

  hardeningDisable = [ "pic" "format" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KVERSION=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  installPhase = ''
    runHook preInstall
    export MODULE_DIR="$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/input/"
    mkdir -p $MODULE_DIR
    cp -r *.ko $MODULE_DIR/ || true
    runHook postInstall
  '';

  meta = {
    description = "A Linux kernel module for the MacBook Pro 2016 Touch Bar.";
    homepage = "https://github.com/maximiliani/nixos";
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux;
  };
}
