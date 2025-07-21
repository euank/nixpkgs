{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "claude-squad";
  version = "1.0.10";

  src = fetchFromGitHub {
    owner = "smtg-ai";
    repo = "claude-squad";
    rev = "v${version}";
    sha256 = "";
  };

  vendorHash = "sha256-LKJXoXZS866UfJ+Edwf6AkAZmTV2Q1OI1mZfbsxHb3s=";

  meta = with lib; {
    description = "Manage multiple AI terminal agents like Claude Code, Aider, Codex, OpenCode, and Amp.";
    homepage = "https://smtg-ai.github.io/claude-squad/";
    license = licenses.agpl3;
    maintainers = with maintainers; [ euank ];
    mainProgram = "cs";
  };
}
