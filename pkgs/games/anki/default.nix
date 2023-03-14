{ lib
, stdenv
, bash
, buildEnv
, fetchFromGitHub
, fetchYarnDeps
, fixup_yarn_lock
, lame
, mpv-unwrapped
, ninja
, nodePackages
, nodejs
, nodejs-slim
, pkg-config
, protobuf
, python39
, qt6
, rsync
, rustPlatform
, symlinkJoin
, writeShellScriptBin
, yarn
, CoreAudio
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

  # run with 'python -m black' as part of the build process
  anki-build-python = python39.withPackages (ps: with ps; [
    protobuf
    black
  ]);

  # The runner is responsible for running the build.
  # We stub out some of what it does below
  anki-runner = rustPlatform.buildRustPackage {
    pname = "anki-build-runner";
    inherit version src;
    cargoHash = "sha256-3ly104TQHY32W7ZSnoQwyRYtdBKfTr7fwnzMG6k8qVk=";

    buildAndTestSubdir = "build/runner";

    nativeBuildInputs = [ pkg-config ];

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

  # anki-i18n is localization stuff, we build it so that runner doesn't try to
  # build this in an impure way
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

  # We build rsbridge with nix, and then put it in the right location so ninja
  # doesn't try to build it itself.
  anki-rsbridge = rustPlatform.buildRustPackage {
    pname = "anki-build-rsbridge";
    inherit version src;
    cargoHash = "sha256-vRd6qgZF+5R/VtgJxzbvr4nWmaTGfL/Bc4eqQADbjTg=";

    buildAndTestSubdir = "pylib/rsbridge";
    buildFeatures = if stdenv.isDarwin then [ "native-tls" ] else [ "rustls" ];

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

  # anki shells out to git to check its revision, and also to update submodules
  # We don't actually need the submodules, so we stub that out
  fakeGit = writeShellScriptBin "git" ''
    #!${bash}/bin/bash

    case "$*" in
      "rev-parse --short=8 HEAD")
        echo ${builtins.substring 0 8 rev}
      ;;
      *"submodule update "*)
        exit 0
      ;;
      *)
        echo "Unrecognized git: $@"
        exit 1
      ;;
    esac
  '';

  # we built a bunch of rust packages above, so we can just not build them when
  # the runner tries to.
  # We mock this out with very specific matching so that if, for example, the
  # build system adds a new '--features' flag, we'll error out here on update
  # and know to then update our rust builds above.
  fakeCargo = writeShellScriptBin "cargo" ''
    #!${bash}/bin/bash

    case "$*" in
      "run -p configure")
        exec ${anki-configurator}/bin/configure
        ;;
      "build --locked -p configure -p runner" | "build --locked -p rsbridge" | "build --release --locked -p anki_i18n")
        exit 0
        ;;
      "build --release --locked -p rsbridge --features rustls" | "build --locked -p archives --features rustls")
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

  # We don't want to run pip-sync, it does network-io
  fakePipSync = writeShellScriptBin "pip-sync" ''
    exit 0
  '';

  # archives is the part of their build system that downloads and checks shasums. We don't want their system downloading stuff, so we mock it out entirely
  fakeArchive = writeShellScriptBin "archives" ''
    1>&2 echo "Not archives: $@"
    exit 0
  '';

  # corepack is some nodejs thing that gets called, idk, seems bad
  fakeCorepack = writeShellScriptBin "corepack" ''
    1>&2 echo "Fake corepack: $@"
    exit 0
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
      anki-build-python
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

  outputs = [ "out" "doc" "man" ];

  patches = [
    ./gl-fixup.patch
    ./no-update-check.patch
  ];

  buildInputs = [
    anki-rsbridge
    qt6.qtbase
    python39.pkgs.protobuf
  ];
  nativeBuildInputs = [
    fakeCargo
    fakeCorepack
    fakeGit
    fixup_yarn_lock
    offlineYarn

    ninja-bin
    python39.pkgs.protobuf
    qt6.wrapQtAppsHook
    rsync
  ];
  propagatedBuildInputs = with python39.pkgs; [
    # This rather long list came from running:
    #    grep --no-filename -oE "^[^ =]*" python/{requirements.base.txt,requirements.bundle.txt,requirements.qt6_4.txt} | \
    #      sort | uniq | grep -v "^#$"
    # in their repo at the git tag for this version
    # There's probably a more elegant way, but the above extracted all the
    # names, without version numbers, of their python dependencies. The hope is
    # that nixpkgs versions are "close enough"
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
  ] ++ lib.optionals stdenv.isDarwin [ CoreAudio ];

  # Activate optimizations
  RELEASE = "1";

  PROTOC_BINARY = "${protobuf}/bin/protoc";
  NODE_BINARY = "${nodejs}/bin/node";

  inherit yarnOfflineCache;

  buildPhase = ''
    export RUST_BACKTRACE=1
    export RUST_LOG=debug

    mkdir -p out/rust/{debug,release} \
             out/rslib/i18n \
             out/extracted/{python/libs,node/bin} \
             out/pylib/anki \
             out/wheels \
             .git

    echo ${builtins.substring 0 8 rev} > out/buildhash
    touch out/env
    touch .git/HEAD

    ln -vsf ${pyEnv} ./out/pyenv
    ln -vsf ${pyEnv} ./out/pyenv-qt5
    ln -vsf ${anki-runner}/bin/runner ./out/rust/debug/runner
    ln -vsf ${anki-configurator}/bin/configure ./out/rust/debug/configure
    ln -vsf ${fakeArchive}/bin/archives ./out/rust/debug/archives
    ln -vsf ${offlineYarn}/bin/yarn out/extracted/node/bin/yarn
    ln -vsf ${anki-i18n} out/rslib/i18n/strings.json
    rsync --chmod +w -avP ${anki-nodemodules}/ out/node_modules/
    ln -vsf out/node_modules node_modules

    ln -vsf ${anki-rsbridge}/lib/* out/extracted/python/libs/
    ln -vsf ${anki-rsbridge}/lib/* out/rust/release/librsbridge.so

    export HOME=$NIX_BUILD_TOP
    yarn config --offline set yarn-offline-mirror $yarnOfflineCache
    fixup_yarn_lock yarn.lock
    patch -p1 < ts/patches/*

    ${anki-configurator}/bin/configure
    PIP_USER=1 ${anki-runner}/bin/runner build wheels
  '';

  doCheck = false;
  preInstall = ''
    mkdir dist
    mv out/wheels/* dist
  '';

  postInstall = ''
    install -D -t $out/share/applications qt/bundle/lin/anki.desktop
    install -D -t $doc/share/doc/anki README* LICENSE*
    install -D -t $man/share/man/man1 qt/bundle/lin/anki.1
    install -D -t $out/share/mime/packages qt/bundle/lin/anki.xml
    install -D -t $out/share/pixmaps qt/bundle/lin/anki.{png,xpm}
  '';

  dontWrapQtApps = true;
  preFixup = ''
    makeWrapperArgs+=(
      "''${qtWrapperArgs[@]}"
      --prefix PATH ':' "${lame}/bin:${mpv-unwrapped}/bin"
    )
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
    maintainers = with maintainers; [ oxij Profpatsch euank ];
  };
}
