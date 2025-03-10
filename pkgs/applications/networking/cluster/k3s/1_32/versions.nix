{
  k3sVersion = "1.32.2+k3s3";
  k3sCommit = "f1dc6618abe5134a49a872bf548171e46b8d4ecc";
  k3sRepoSha256 = "1x6zafkvkfqi67n0lxg22xvbirmfrs5vfhi9jjfpw0350qwfcszw";
  k3sVendorHash = "sha256-zOC3uL7ZVfCUYp1igGz0wX0N7Rrnfw1poS8fSD7RFbk=";
  chartVersions = import ./chart-versions.nix;
  imagesVersions = builtins.fromJSON (builtins.readFile ./images-versions.json);
  k3sRootVersion = "0.14.1";
  k3sRootSha256 = "0svbi42agqxqh5q2ri7xmaw2a2c70s7q5y587ls0qkflw5vx4sl7";
  k3sCNIVersion = "1.6.0-k3s1";
  k3sCNISha256 = "0g7zczvwba5xqawk37b0v96xysdwanyf1grxn3l3lhxsgjjsmkd7";
  containerdVersion = "1.7.23-k3s2";
  containerdSha256 = "0lp9vxq7xj74wa7hbivvl5hwg2wzqgsxav22wa0p1l7lc1dqw8dm";
  criCtlVersion = "1.31.0-k3s2";
}
