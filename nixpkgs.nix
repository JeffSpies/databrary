(import
  ((import <nixpkgs> {}).fetchFromGitHub {
    owner= "reflex-frp";
    repo = "reflex-platform";
    rev = "bdc94c605bf72f1a65cbd12075fbb661e28b24ea";
    sha256 = "1i4zk7xc2x8yj9ms4gsg70immm29dp8vzqq7gdzxig5i3kva0a61";
}) {}).nixpkgs
