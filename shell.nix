{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    ghp-import
    (python312.withPackages (
      ps: with ps; [
        markdown
        pelican
      ]
    ))
  ];
}
