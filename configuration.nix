# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  main-user = "commandertvis";
  host-name = "commandertvis-ms7a15";
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz";

  android-nixpkgs = pkgs.callPackage (import (
    builtins.fetchGit { url = "https://github.com/tadfisher/android-nixpkgs.git"; }
  )) { channel = "stable"; };

  android-sdk = android-nixpkgs.sdk (
    sdkPkgs: with sdkPkgs; [
      cmdline-tools-latest
      platform-tools
      emulator

      build-tools-34-0-0
      platforms-android-34
      sources-android-34

      build-tools-35-0-0
      platforms-android-35
      sources-android-35
      system-images-android-35-google-apis-playstore-x86-64
    ]
  );

  outline-manager = pkgs.callPackage (
    { appimageTools, fetchurl }:
    let
      pname = "outline-manager";
      version = "1.17.0";
      src = fetchurl {
        url = "https://s3.amazonaws.com/outline-releases/manager/linux/${version}/1/Outline-Manager.AppImage";
        hash = "sha256-dK44GouoXAWlIiPpZeXI86sILJ4AzlQEe3XwTPua9mc=";
      };

      appimageContents = appimageTools.extract { inherit pname version src; };
    in
    appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -m 444 -D ${appimageContents}/@outlineserver_manager.desktop $out/share/applications/@outlineserver_manager.desktop
        install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/@outlineserver_manager.png \
          $out/share/icons/hicolor/512x512/apps/@outlineserver_manager.png
        substituteInPlace $out/share/applications/@outlineserver_manager.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      '';
    }
  ) { };
in
{
  imports = [
    ./hardware-configuration.nix
    (import "${home-manager}/nixos")
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;

    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };

    systemd-boot.enable = false;
  };

  hardware = {
    bluetooth.enable = true;
    graphics.enable = true;

    nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  networking = {
    hostName = host-name;
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = [ "nvidia" ];
    };

    libinput.enable = true;
    desktopManager.plasma6.enable = true;

    displayManager = {
      enable = true;
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
    };

    syncthing = {
      enable = true;
      group = "syncthing";
      user = main-user;
      configDir = "/home/${main-user}/Documents/.config/syncthing";
    };

    tailscale.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        UsePAM = false;
      };
    };

    udev.packages = [ pkgs.android-udev-rules ];
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    kate
    khelpcenter
  ];

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command
    '';

    optimise.automatic = true;

    settings = {
      trusted-users = [
        "root"
        main-user
      ];
      allowed-users = [ "@wheel" ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    tree
    vscode
    vivaldi
    yakuake
    neofetch
    nixfmt-rfc-style
    nil
    vlc
    curl
    gource
    git
    syncthing
    btrfs-assistant
    file
    jetbrains-mono
  ];

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";
    variables = {
      NIX_REMOTE = "daemon";
      ANDROID_HOME = "${android-sdk}/share/android-sdk";
      ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";
    };
    etc."1password/custom_allowed_browsers" = {
      text = "vivaldi-bin";
      mode = "0755";
    };
  };

  security.polkit.enable = true;

  programs = {
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ main-user ];
    };

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    partition-manager.enable = true;

    steam = {
      enable = true;
      # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      # localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };

  users.users.${main-user} = {
    isNormalUser = true;
    home = "/home/${main-user}";

    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "syncthing"
      "docker"
      "kvm"
    ];

    packages = with pkgs; [
      telegram-desktop
      discord
      anki-bin
      qdirstat
      gimp
      jetbrains-toolbox
      slack
      obsidian
      appimage-run
      outline-manager
      prismlauncher
      libreoffice-qt6
      zoom-us
      yt-dlp
      android-sdk
      yarn
      nodejs_23
      mpv
      teams-for-linux
      poetry
    ];

    openssh.authorizedKeys.keyFiles = [ /etc/nixos/ssh/authorized_keys ];
  };

  home-manager.users.${main-user} = {
    programs = {
      git = {
        enable = true;
        userName = "Iaroslav Postovalov";
        userEmail = "postovalovya@gmail.com";

        extraConfig = {
          commit.gpgsign = true;
          gpg.format = "ssh";
          user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhrNPHMWPV7gGuPheIX4POXrlPNNL2h/KMAJsAuSA0W";
          "gpg \"ssh\"".program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };
      };
      gpg = {
        enable = true;
      };
    };

    # https://github.com/nix-community/home-manager/issues/322
    # programs.ssh = {
    #   enable = true;
    #   extraConfig = ''
    #     Host *
    #         IdentityAgent ~/.1password/agent.sock
    #   '';
    # };

    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.11";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = false;

  system = {
    autoUpgrade.channel = "https://nixos.org/channels/nixos-24.11/";

    # Copy the NixOS configuration file and link it from the resulting system
    # (/run/current-system/configuration.nix). This is useful in case you
    # accidentally delete configuration.nix.
    copySystemConfiguration = true;

    # This option defines the first version of NixOS you have installed on this particular machine,
    # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
    #
    # Most users should NEVER change this value after the initial install, for any reason,
    # even if you've upgraded your system to a new NixOS release.
    #
    # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
    # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
    # to actually do that.
    #
    # This value being lower than the current NixOS release does NOT mean your system is
    # out of date, out of support, or vulnerable.
    #
    # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
    # and migrated your data accordingly.
    #
    # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    stateVersion = "24.11"; # Did you read the comment?
  };
}
