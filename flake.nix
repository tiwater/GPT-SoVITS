{
  description = "A Nix-flake-based Python development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    nix-gl-host = {
      url = "github:numtide/nix-gl-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-gl-host }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
            permittedInsecurePackages = [
              "python3.10-gradio-3.44.3"
            ];
          };
        };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs, system }: {
        default = let pythonPkgs = pkgs.python310Packages; in pkgs.mkShell {
          packages = with pythonPkgs; [ python-lsp-server ];
          buildInputs = with pkgs; [ ffmpeg ] ++
            (with pythonPkgs;  [
              torch
              torchaudio
              gradio
              fastapi
              numpy
              scipy
              tensorboard
              librosa
              numba
              pytorch-lightning
              ffmpeg-python
              onnxruntime
              tqdm
              # funasr
              # cn2an
              pypinyin
              # g2p_en
              # modelscope
              sentencepiece
              transformers
              chardet
              # PyYAML
              psutil
              # jieba_fast
              jieba
              # LangSegment
              # Faster_Whisper
              # wordsegment

              # This has to be built from source; otherwise, there will be glibc conflicts!
              (buildPythonPackage rec {
                pname = "pyopenjtalk";
                version = "0.3.3";
                # pyproject = true;

                src = fetchPypi {
                  inherit pname version;
                  hash = "sha256-Xr9GOLjCqzsqfXbQ28TWpkG8Uz93MxJNbelHjqffahk="; # pkgs.lib.fakeHash;
                };

                nativeBuildInputs = [ pkgs.cmake ];
                # Have to skip configure, otherwise it will fails
                configurePhase = ''
                  echo "Skip the configure phase"
                '';
                propagatedBuildInputs = [ setuptools numpy pip ];
                doCheck = false;
                # dependencies = [ numpy tqdm ];
              })
            ]) ++
            [ nix-gl-host.defaultPackage.${system} ];
          shellHook = ''
            export LD_LIBRARY_PATH="$(nixglhost -p):${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
            if [[ ! -d .venv ]]; then
              echo "No virtual env found at ./.venv, creating a new virtual env linked to the Python site defined with Nix"
              ${pkgs.lib.getExe pkgs.python310} -m venv .venv --copies
            fi
            source .venv/bin/activate
            echo "Nix development shell loaded."
          '';
        };
      });
    };
}
