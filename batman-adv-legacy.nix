{ stdenv, fetchFromGitHub, kernel }:

stdenv.mkDerivation rec {
  pname = "batman-adv-legacy";
  version = "2013.4.0-65";

  src = fetchFromGitHub {
    owner = "freifunk-gluon";
    repo = "batman-adv-legacy";
    rev = "d8bfd8e4b5bd45023b3d0201ee035f7af3dac44a";
    sha256 = "sha256-9nivJU+GndvlgD2bh3Y2213Qv79gDRagmsCzuN9zt/Y=";
  };

  patches = [
    ./batadv-legacy.patch
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  hardeningDisable = [ "pic" ];

  preBuild = ''
    makeFlags="KERNELPATH=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    sed -i -e "s,INSTALL_MOD_DIR=,INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=," \
      -e /depmod/d Makefile
  '';

  meta = {
    homepage = "https://www.open-mesh.org/projects/batman-adv/wiki/Wiki";
    description = "B.A.T.M.A.N. routing protocol in a linux kernel module for layer 2";
  };
}
