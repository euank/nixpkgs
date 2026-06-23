{
  lib,
  buildPythonPackage,
  stdenv,
  fetchFromGitHub,
  binaryornot,
  build,
  chardet,
  cookiecutter,
  dmgbuild,
  gitpython,
  httpx,
  httpx-retries,
  packaging,
  pip,
  platformdirs,
  psutil,
  pytestCheckHook,
  python-dateutil,
  pythonOlder,
  rich,
  setuptools,
  setuptools-scm,
  tenacity,
  tomli,
  tomli-w,
  truststore,
  wheel,
}:

buildPythonPackage rec {
  pname = "briefcase";
  version = "0.4.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "beeware";
    repo = "briefcase";
    tag = "v${version}";
    hash = "sha256-Loke+Zjqo90xO/J3uqmrqRkP/MxcgvPsRI5g+r3qoSM=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "setuptools==82.0.1" "setuptools" \
      --replace-fail "setuptools_scm==10.0.5" "setuptools_scm"
  '';

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    binaryornot
    build
    chardet
    cookiecutter
    gitpython
    httpx
    packaging
    pip
    platformdirs
    psutil
    python-dateutil
    rich
    setuptools
    tenacity
    tomli-w
    truststore
    wheel
  ]
  ++ lib.optionals (pythonOlder "3.11") [
    tomli
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    dmgbuild
  ];

  nativeCheckInputs = [
    httpx-retries
    pytestCheckHook
  ];

  preCheck = ''
    export HOME=$TMPDIR
  '';

  disabledTests = [
    # These tests check that upstream tool download URLs are resolvable.
    "test_cmdline_tools_url"
    "test_download_missing"
    "test_download_url"
    "test_rcedit_url"
    "test_successful_jdk_download"
  ];

  meta = {
    description = "Tools to support converting a Python project into a standalone native application.";
    mainProgram = "briefcase";
    homepage = "https://briefcase.beeware.org/en/stable/";
    changelog = "https://github.com/${src.owner}/${src.repo}/releases/tag/${src.tag}";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ euank ];
  };
}
