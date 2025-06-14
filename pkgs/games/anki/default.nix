{
  lib,
  stdenv,

  writableTmpDirAsHomeHook,
  buildEnv,
  cargo,
  fetchFromGitHub,
  installShellFiles,
  lame,
  mpv-unwrapped,
  ninja,
  callPackage,
  nixosTests,
  nodejs,
  jq,
  protobuf,
  python3,
  qt6,
  rsync,
  rustPlatform,
  uv,
  writeShellScriptBin,
  yarn,
  yarn-berry_4,

  swift,
  fetchgit,

  mesa,
}:

let
  yarn-berry = yarn-berry_4;

  pname = "anki";
  version = "25.07.1";
  rev = "a83a6b5928c6563d12e7b66d4f7b7b2f51b6f22b";

  srcHash = "sha256-OiyuvSRJu6urjf5b78F8A5Z/zoOXoErCpzCKcxNm8Jk=";
  cargoHash = "sha256-611vbe0RtmaCuEkX4wEtjvuYkOGGrxkl/r2KeRzrdnk=";
  yarnHash = "sha256-Hb3HGIB0HPM6LXkfLIbPONFBTqWPdTrvYP2CeUsIVTE=";
  uvHash = "sha256-7a0PRgaZtRoV0C8IbBq3ipRUXMW8LNbctGxU9ej1pq4=";

  src = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki";
    rev = version;
    hash = srcHash;
    fetchSubmodules = true;
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = cargoHash;
  };

  # a wrapper for yarn to skip 'install'
  # We do this because we need to patchShebangs after install, so we do it
  # ourselves beforehand.
  # We also, confusingly, have to use yarn-berry to handle the lockfile (anki's
  # lockfile is too new for yarn), but have to use 'yarn' here, because anki's
  # build system uses yarn-1 style flags and such.
  # I think what's going on here is that yarn-1 in anki's normal build system
  # ends up noticing the yarn-file is too new and shelling out to yarn-berry
  # itself.
  noInstallYarn = writeShellScriptBin "yarn" ''
    [[ "$1" == "install" ]] && exit 0
    exec ${yarn}/bin/yarn "$@"
  '';

  anki-build-python = python3.withPackages (ps: with ps; [ mypy-protobuf ]);

  pyEnv = buildEnv {
    name = "anki-pyenv-${version}";
    paths = with python3.pkgs; [
      pip
      anki-build-python
    ];
    pathsToLink = [ "/bin" ];
  };
in
python3.pkgs.buildPythonApplication rec {
  inherit pname version;

  outputs = [
    "out"
    "doc"
    "man"
  ];

  inherit src;

  patches = [
    ./patches/disable-auto-update.patch
    ./patches/remove-the-gl-library-workaround.patch
    ./patches/skip-formatting-python-code.patch
    ./patches/fix-offline-uv-build.patch
    # Used in with-addons.nix
    ./patches/allow-setting-addons-folder.patch
  ];

  inherit cargoDeps;

  missingHashes = ./missing-hashes.json;
  yarnOfflineCache = yarn-berry.fetchYarnBerryDeps {
    inherit missingHashes;
    yarnLock = "${src}/yarn.lock";
    hash = yarnHash;
  };

  uvOfflineCache = stdenv.mkDerivation {
    pname = "anki-uv-deps";
    inherit version src;

    UV_NO_MANAGED_PYTHON = true;
    UV_SYSTEM_PYTHON = true;

    nativeBuildInputs = [
      python3
      uv
    ];

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = uvHash;

    dontBuild = true;

    installPhase = ''
      python3 --version
      uv sync \
        --locked --reinstall --cache-dir $out --python python3
      # don't cache the interpreter, that leads to a store reference to python,
      # which we don't want
      rm -rf $out/interpreter-v4
    '';
  };

  nativeBuildInputs = [
    cargo
    installShellFiles
    jq
    ninja
    nodejs
    qt6.wrapQtAppsHook
    rsync
    rustPlatform.cargoSetupHook
    writableTmpDirAsHomeHook
    yarn-berry_4.yarnBerryConfigHook
  ] ++ lib.optional stdenv.hostPlatform.isDarwin swift;

  buildInputs = [
    qt6.qtbase
    qt6.qtsvg
  ] ++ lib.optional stdenv.hostPlatform.isLinux qt6.qtwayland;

  propagatedBuildInputs = with python3.pkgs; [
    # This rather long list came from running:
    #    grep --no-filename -oE "^[^ =]*" python/{requirements.base.txt,requirements.bundle.txt,requirements.qt6_lin.txt} | \
    #      sort | uniq | grep -v "^#$"
    # in their repo at the git tag for this version
    # There's probably a more elegant way, but the above extracted all the
    # names, without version numbers, of their python dependencies. The hope is
    # that nixpkgs versions are "close enough"
    # I then removed the ones the check phase failed on (pythonCatchConflictsPhase)
    attrs
    beautifulsoup4
    blinker
    build
    certifi
    charset-normalizer
    click
    colorama
    decorator
    flask
    flask-cors
    google-api-python-client
    idna
    importlib-metadata
    itsdangerous
    jinja2
    jsonschema
    markdown
    markupsafe
    orjson
    packaging
    pip
    pip-system-certs
    pip-tools
    protobuf
    pyproject-hooks
    pyqt6
    pyqt6-sip
    pyqt6-webengine
    pyrsistent
    pysocks
    requests
    send2trash
    setuptools
    soupsieve
    tomli
    urllib3
    waitress
    werkzeug
    wheel
    wrapt
    zipp
  ];

  nativeCheckInputs = with python3.pkgs; [
    pytest
    mock
    astroid
  ];

  # tests fail with too many open files
  # TODO: verify if this is still true (I can't, no mac)
  doCheck = !stdenv.hostPlatform.isDarwin;

  checkFlags = [
    # this test is flaky, see https://github.com/ankitects/anki/issues/3619
    # also remove from anki-sync-server when removing this
    "--skip=deckconfig::update::test::should_keep_at_least_one_remaining_relearning_step"
  ];

  dontUseNinjaInstall = false;
  dontWrapQtApps = true;

  env = {
    # Activate optimizations
    RELEASE = true;

    # https://github.com/ankitects/anki/blob/24.11/docs/linux.md#packaging-considerations
    OFFLINE_BUILD = "1";
    NODE_BINARY = lib.getExe nodejs;
    PROTOC_BINARY = lib.getExe protobuf;
    PYTHON_BINARY = lib.getExe python3;
    UV_BINARY = lib.getExe uv;
    UV_NO_MANAGED_PYTHON = "1";
    UV_SYSTEM_PYTHON = true;
    UV_PYTHON_DOWNLOADS = "never";
    UV_OFFLINE = "1";
  };

  buildPhase = ''
    export RUST_BACKTRACE=1
    export RUST_LOG=debug

    mkdir -p out/pylib/anki .git

    echo ${builtins.substring 0 8 rev} > out/buildhash
    echo ${python3.version} > .python-version

    mkdir ./out/pyenv
    rsync -av "${pyEnv}/" ./out/pyenv
    chmod +w ./out/pyenv

    # put the uv cache dir in a writeable location because for some reason uv
    # tries to write to it???
    mkdir ./out/uv
    rsync -av "${uvOfflineCache}/" ./out/uv
    export UV_CACHE_DIR=$PWD/out/uv
    chmod -R +w ./out/uv

    mv node_modules out

    # Run everything else
    patchShebangs ./ninja

    # Necessary for yarn to not complain about 'corepack'
    jq 'del(.packageManager)' package.json > package.json.tmp && mv package.json.tmp package.json
    YARN_BINARY="${lib.getExe noInstallYarn}" PIP_USER=1 ./ninja build wheels
  '';

  # mimic https://github.com/ankitects/anki/blob/76d8807315fcc2675e7fa44d9ddf3d4608efc487/build/ninja_gen/src/python.rs#L232-L250
  checkPhase =
    let
      disabledTestsString =
        lib.pipe
          [
            # assumes / is not writeable, somehow fails on nix-portable brwap
            "test_create_open"
          ]
          [
            (lib.map (test: "not ${test}"))
            (lib.concatStringsSep " and ")
            lib.escapeShellArg
          ];

    in
    ''
      runHook preCheck
      HOME=$TMP ANKI_TEST_MODE=1 PYTHONPATH=$PYTHONPATH:$PWD/out/pylib \
        pytest -p no:cacheprovider pylib/tests -k ${disabledTestsString}
      HOME=$TMP ANKI_TEST_MODE=1 PYTHONPATH=$PYTHONPATH:$PWD/out/pylib:$PWD/pylib:$PWD/out/qt \
        pytest -p no:cacheprovider qt/tests -k ${disabledTestsString}
      runHook postCheck
    '';

  preInstall = ''
    mkdir dist
    mv out/wheels/* dist
  '';

  postInstall = ''
    install -D -t $out/share/applications qt/bundle/lin/anki.desktop
    install -D -t $doc/share/doc/anki README* LICENSE*
    install -D -t $out/share/mime/packages qt/bundle/lin/anki.xml
    install -D -t $out/share/pixmaps qt/bundle/lin/anki.{png,xpm}
    installManPage qt/bundle/lin/anki.1
  '';

  preFixup = ''
    makeWrapperArgs+=(
      "''${qtWrapperArgs[@]}"
      --prefix PATH ':' "${lame}/bin:${mpv-unwrapped}/bin"
    )
  '';

  passthru = {
    withAddons = ankiAddons: callPackage ./with-addons.nix { inherit ankiAddons; };
    tests.anki-sync-server = nixosTests.anki-sync-server;
  };

  meta = with lib; {
    description = "Spaced repetition flashcard program";
    mainProgram = "anki";
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
    homepage = "https://apps.ankiweb.net";
    license = licenses.agpl3Plus;
    inherit (mesa.meta) platforms;
    maintainers = with maintainers; [
      euank
      junestepp
      oxij
    ];
    # Reported to crash at launch on darwin (as of 2.1.65)
    broken = stdenv.hostPlatform.isDarwin;
  };
}
