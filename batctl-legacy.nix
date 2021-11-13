{ lib, stdenv, fetchurl, pkg-config, libnl }:

stdenv.mkDerivation rec {
  pname = "batctl";
  version = "2013.4.0";

  src = fetchurl {
    url = "https://downloads.open-mesh.org/batman/releases/batman-adv-${version}/${pname}-${version}.tar.gz";
    sha256 = "TerjtmZNDROs96js50F1oxpy/lj7FcuREqmiAUsyy0w=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libnl ];

  preBuild = ''
    makeFlags="PREFIX=$out PKG_CONFIG=${pkg-config}/bin/${pkg-config.targetPrefix}pkg-config"
  '';

  meta = {
    homepage = "https://www.open-mesh.org/projects/batman-adv/wiki/Wiki";
    description = "B.A.T.M.A.N. routing protocol in a linux kernel module for layer 2, control tool";
    license = lib.licenses.gpl2;
    maintainers = with lib.maintainers; [ fpletz ];
    platforms = with lib.platforms; linux;
  };
}

