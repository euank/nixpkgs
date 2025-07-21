{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
  writableTmpDirAsHomeHook,
}:

buildGoModule rec {
  pname = "claude-squad";
  version = "1.0.10";

  src = fetchFromGitHub {
    owner = "smtg-ai";
    repo = "claude-squad";
    rev = "v${version}";
    sha256 = "sha256-oXjVMcobJ4sLh7m9Zc2EAKAL90FZ/3NkA5byfDXJnSk=";
  };

  vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";

  nativeBuildInputs = [
    # for tests
    git
    writableTmpDirAsHomeHook
  ];

  meta = with lib; {
    description = "Manage multiple AI terminal agents like Claude Code, Aider, Codex, OpenCode, and Amp.";
    homepage = "https://smtg-ai.github.io/claude-squad/";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ euank ];
    mainProgram = "claude-squad";
  };
}
