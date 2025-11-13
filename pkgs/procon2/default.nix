{
  lib,
  python3,
  libusb1,
  makeWrapper,
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      pyusb
    ]
  );
in
python3.pkgs.buildPythonApplication rec {
  pname = "procon2-init";
  version = "0.1.0";

  src = ./.;

  format = "other";

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    pythonEnv
    libusb1
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Copy the Python script
    cp procon2-init.py $out/bin/procon2-init.py

    # Create executable wrapper
    cat > $out/bin/procon2-init << 'EOF'
    #!${pythonEnv}/bin/python3
    import sys
    import os
    sys.path.insert(0, os.path.dirname(__file__))
    exec(open(os.path.join(os.path.dirname(__file__), 'procon2-init.py')).read())
    EOF

    chmod +x $out/bin/procon2-init

    # Wrap to ensure libusb is found at runtime
    wrapProgram $out/bin/procon2-init \
      --prefix LD_LIBRARY_PATH : "${libusb1}/lib" \
      --prefix PATH : "${pythonEnv}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Initializer for Nintendo Switch 2 Pro Controller";
    longDescription = ''
      Sends initialization sequence to Nintendo Switch 2 Pro Controller
      to enable HID input on Linux. Based on reverse engineering of the
      controller's USB protocol by https://github.com/HandHeldLegend
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ toph ];
  };
}
