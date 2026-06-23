{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  rustPlatform,
  pythonOlder,
  pytestCheckHook,
  tomli,
  typer,
}:

buildPythonPackage rec {
  pname = "complexipy";
  version = "5.6.1";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "rohaquinlop";
    repo = "complexipy";
    tag = version;
    hash = "sha256-YfLkKJghUEm0RmJihxOYg+pbhU65irb27kkUVCszhRQ=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = "sha256-bSJCH41jJTxRhCsth1CzJ4dR2O7uLkoIuU+IkxknNjY=";
  };

  build-system = [
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];

  dependencies = [
    tomli
    typer
  ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  preCheck = ''
    rm -r complexipy
  '';

  pythonImportsCheck = [ "complexipy" ];

  meta = {
    description = "Fast Python cognitive complexity analyzer written in Rust";
    mainProgram = "complexipy";
    homepage = "https://rohaquinlop.github.io/complexipy/";
    changelog = "https://github.com/rohaquinlop/complexipy/releases/tag/${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ euank ];
  };
}
