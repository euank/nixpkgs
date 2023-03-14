{ lib
, stdenv
, bash
, buildEnv
, fetchFromGitHub
, fetchYarnDeps
, fixup_yarn_lock
, ninja
, nodePackages
, nodejs
, nodejs-slim
, openssl
, pkg-config
, protobuf
, python39
, qt6
, rsync
, rustPlatform
, symlinkJoin
, writeShellScriptBin
, yarn
}:

let
  pname = "anki";
  version = "2.1.60";
  rev = "76d8807315fcc2675e7fa44d9ddf3d4608efc487";

  src = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki";
    rev = version;
    sha256 = "sha256-hNrf6asxF7r7QK2XO150yiRjyHAYKN8OFCFYX0SAiwA=";
    fetchSubmodules = true;
  };

  anki-python = python39.withPackages (ps: with ps; [
    attrs
    beautifulsoup4
    build
    certifi
    charset-normalizer
    click
    colorama
    decorator
    distro
    flask
    flask-cors
    idna
    importlib-metadata
    itsdangerous
    jinja2
    jsonschema
    markdown
    markupsafe
    orjson
    packaging
    pep517
    pip
    pip-tools
    protobuf3
    pyparsing
    pyqt6
    pyqt6-sip
    pyqt6-webengine
    pyrsistent
    pysocks
    requests
    send2trash
    setuptools
    six
    soupsieve
    tomli
    urllib3
    waitress
    werkzeug
    wheel
    zipp

    black
  ]);

  # The runner is responsible for running the build
  anki-runner = rustPlatform.buildRustPackage {
    pname = "anki-build-runner";
    inherit version src;
    cargoHash = "sha256-3ly104TQHY32W7ZSnoQwyRYtdBKfTr7fwnzMG6k8qVk=";

    buildAndTestSubdir = "build/runner";

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ];

    doCheck = false;
  };

  # The configurator generates the build.ninja
  anki-configurator = rustPlatform.buildRustPackage {
    pname = "anki-build-configurator";
    inherit version src;
    cargoHash = "sha256-C6kOqYvbqcSBwGVhz02Ul3kdmFRvG9YqQ+9ZNquMLLg=";

    buildAndTestSubdir = "build/configure";

    doCheck = false;
  };

  anki-i18n = rustPlatform.buildRustPackage {
    pname = "anki-build-i18n";
    inherit version src;
    cargoHash = "sha256-9DfenBEEw6GncdhwDSFeWZYhLqf30oECCSwnDeG175c=";

    buildAndTestSubdir = "rslib/i18n";

    preBuild = ''
      mkdir -p out/rslib/i18n/
    '';

    installPhase = ''
      mv out/rslib/i18n/strings.json $out
    '';

    doCheck = false;
  };

  anki-rsbridge = rustPlatform.buildRustPackage {
    pname = "anki-build-rsbridge";
    inherit version src;
    cargoHash = "sha256-vRd6qgZF+5R/VtgJxzbvr4nWmaTGfL/Bc4eqQADbjTg=";

    buildAndTestSubdir = "pylib/rsbridge";

    PROTOC_BINARY = "${protobuf}/bin/protoc";
    preBuild = ''
      mkdir -p out/rslib/i18n/
      echo ${builtins.substring 0 8 rev} > out/buildhash
    '';

    installPhase = ''
      mkdir -p $out/lib
      mv target/x86_64-unknown-linux-gnu/release/librsbridge.so $out/lib
    '';

    doCheck = false;
  };

  fakeGit = writeShellScriptBin "git" ''
    #!${bash}/bin/bash

    case "$@" in
      "rev-parse --short=8 HEAD")
        echo ${builtins.substring 0 8 rev}
      ;;
      *submodule*update*)
        exit 0
      ;;
      *)
        echo "Unrecognized git: $@"
        exit 1
      ;;
    esac
  '';

  fakeCargo = writeShellScriptBin "cargo" ''
    #!${bash}/bin/bash

    case "$@" in
      "run -p configure")
        exec ${anki-configurator}/bin/configure
        ;;

      *build*anki_i18n)
        exit 0
        ;;
      *build*runner)
        exit 0
        ;;
      *build*configure)
        exit 0
        ;;
      *build*archives*)
        exit 0
        ;;
      *build*rsbridge*)
        exit 0
        ;;
      *build*)
        1>&2 echo "Not building: cargo $@"
        exit 1
        ;;
      *)
        echo "Unknown cargo command: $@"
        exit 1
        ;;
    esac
  '';

  fakePipSync = writeShellScriptBin "pip-sync" ''
    exit 0
  '';

  fakeArchive = writeShellScriptBin "archives" ''
    1>&2 echo "Not archives: $@"
    exit 0
  '';

  fakeCorepack = writeShellScriptBin "corepack" ''
    1>&2 echo "Fake corepack: $@"
    exit 0
  '';

  fakeRunner = writeShellScriptBin "runner" ''
    #!${bash}/bin/bash

    case "$@" in
      pyenv*requirements*txt)
        exit 0
        ;;
      *)
        ${anki-runner}/bin/runner "$@"
      ;;
    esac
  '';

  offlineYarn = writeShellScriptBin "yarn" ''
    [[ "$1" == "install" ]] && exit 0
    exec ${yarn}/bin/yarn --offline "$@"
  '';

  pyEnv = symlinkJoin {
    name = "anki-pyenv-${version}";
    paths = with python39.pkgs; [
      pip
      fakePipSync
      pyqt6
      anki-python
      build
      mypy
      black
      isort
      pylint
      pytest
      mypy-protobuf
    ];
  };

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    sha256 = "sha256-bAtmMGWi5ETIidFFnG3jzJg2mSBnH5ONO2/Lr9A3PpQ=";
  };

  # https://discourse.nixos.org/t/mkyarnpackage-lockfile-has-incorrect-entry/21586/3
  anki-nodemodules = stdenv.mkDerivation {
    pname = "anki-nodemodules";
    inherit version src yarnOfflineCache;

    nativeBuildInputs = [
      fixup_yarn_lock
      yarn
      nodejs-slim
    ];

    configurePhase = ''
      export HOME=$NIX_BUILD_TOP
      yarn config --offline set yarn-offline-mirror $yarnOfflineCache
      fixup_yarn_lock yarn.lock
      yarn install --offline --frozen-lockfile --ignore-scripts --no-progress --non-interactive
      patchShebangs node_modules/
    '';

    installPhase = ''
      mv node_modules $out
    '';
  };

  # Mask ninja's setup hooks, we just want the binary, not the implicit 'ninja install'
  ninja-bin = buildEnv {
    name = ninja.name;
    paths = [ ninja ];
    pathsToLink = [ "/bin" ];
  };
in
python39.pkgs.buildPythonApplication {
  inherit pname version src;

  patches = [ ./gl-fixup.patch ];

  buildInputs = [ anki-rsbridge qt6.qtbase ];
  nativeBuildInputs = [ ninja-bin fakeGit fakeCargo fakeCorepack rsync offlineYarn fixup_yarn_lock qt6.wrapQtAppsHook ];
  dontWrapQtApps = true;
  propagatedBuildInputs = with python39.pkgs; [
    attrs
    beautifulsoup4
    build
    certifi
    charset-normalizer
    click
    colorama
    decorator
    distro
    flask
    flask-cors
    idna
    importlib-metadata
    itsdangerous
    jinja2
    jsonschema
    markdown
    markupsafe
    orjson
    packaging
    pep517
    pip
    pip-tools
    python39.pkgs.protobuf
    pyparsing
    pyqt6
    pyqt6-sip
    pyqt6-webengine
    pyrsistent
    pysocks
    requests
    send2trash
    setuptools
    six
    soupsieve
    tomli
    urllib3
    waitress
    werkzeug
    zipp
  ];

  # Activate optimizations
  RELEASE = "1";

  PYTHON_BINARY = "${anki-python}/bin/python";
  PROTOC_BINARY = "${protobuf}/bin/protoc";
  NODE_BINARY = "${nodejs}/bin/node";

  inherit yarnOfflineCache;

  buildPhase = ''
    export RUST_BACKTRACE=1
    export RUST_LOG=debug
    mkdir -p out
    echo ${builtins.substring 0 8 rev} > out/buildhash
    touch out/env
    mkdir -p out/rust/debug
    ln -vsf ${pyEnv} ./out/pyenv
    ln -vsf ${pyEnv} ./out/pyenv-qt5
    ln -vsf ${anki-runner}/bin/runner ./out/rust/debug/runner
    ln -vsf ${anki-configurator}/bin/configure ./out/rust/debug/configure
    ln -vsf ${fakeArchive}/bin/archives ./out/rust/debug/archives
    mkdir -p out/extracted/node/bin
    ln -vsf ${offlineYarn}/bin/yarn out/extracted/node/bin/yarn
    mkdir -p .git
    touch .git/HEAD
    mkdir -p out/rslib/i18n
    ln -vsf ${anki-i18n} out/rslib/i18n/strings.json
    rsync -avP ${anki-nodemodules}/ out/node_modules/
    chmod +w ./out/node_modules

    mkdir -p out/extracted/python/libs
    ln -vsf ${anki-rsbridge}/lib/* out/extracted/python/libs/
    mkdir -p out/rust/release
    ln -vsf ${anki-rsbridge}/lib/* out/rust/release/librsbridge.so

    export HOME=$NIX_BUILD_TOP
    yarn config --offline set yarn-offline-mirror $yarnOfflineCache
    fixup_yarn_lock yarn.lock

    mkdir -p out/pylib/anki
    mkdir -p out/wheels/

    ${anki-configurator}/bin/configure
    PIP_USER=1 ${anki-runner}/bin/runner build wheels
  '';

  doCheck = false;
  preInstall = ''
    set -x
    mkdir dist
    mv out/wheels/* dist
    export PYTHONPATH=$PYTHONPATH:${python39.pkgs.protobuf}/lib/python3.9/site-packages
  '';

  postInstall = ''
    ls -alh $out/bin
  '';

  postFixup = ''
    wrapQtApp $out/bin/anki "''${qtWrapperArgs[@]}"
  '';

  meta = with lib; {
    homepage = "https://apps.ankiweb.net/";
    description = "Spaced repetition flashcard program";
    longDescription = ''
      Anki is a program which makes remembering things easy. Because it is a lot
      more efficient than traditional study methods, you can either greatly
      decrease your time spent studying, or greatly increase the amount you learn.

      Anyone who needs to remember things in their daily life can benefit from
      Anki. Since it is content-agnostic and supports images, audio, videos and
      scientific markup (via LaTeX), the possibilities are endless. For example:
      learning a language, studying for medical and law exams, memorizing
      people's names and faces, brushing up on geography, mastering long poems,
      or even practicing guitar chords!
    '';
    license = licenses.agpl3Plus;
    platforms = platforms.mesaPlatforms;
    maintainers = with maintainers; [ oxij Profpatsch ];
  };
}
