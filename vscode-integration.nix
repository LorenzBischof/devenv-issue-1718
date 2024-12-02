{ pkgs, config, lib, ... }:
let
  cfg = config.drupal.vscodeIntegration;
in
{
  options.drupal.vscodeIntegration = {
    enable = lib.mkEnableOption "integration with VS Code";

    vscodeConfigPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.env.DEVENV_ROOT}/.vscode";
    };

    xdebugConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        name = "Listen for XDebug (devenv)";
        type = "php";
        request = "launch";
        hostname = "unix://${config.env.DEVENV_RUNTIME}/xdebug.sock";
      };
    };

    launch = lib.mkOption {
      type = lib.types.attrs;
      default = {
        version = "0.2.0";
        configurations = [ cfg.xdebugConfig ];
      };
    };

    extensions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {
        recommendations = [
          "ValeryanM.vscode-phpsab"
          "dbaeumer.vscode-eslint"
          "xdebug.php-debug"
          "bmewburn.vscode-intelephense-client"
        ];
        unwantedRecommendations = [
          "vscode.php"
        ];
      };
    };

    settings = lib.mkOption
      {
        type = lib.types.attrs;
        default = {
          # https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code#s-editor-settings
          # 'The following settings are related to basic formatting for PHP, CSS, JavaScript or HTML files.'
          "breadcrumbs.enabled" = true;
          "css.validate" = true;
          "diffEditor.ignoreTrimWhitespace" = false;
          "editor.tabSize" = 2;
          "editor.autoIndent" = "full";
          "editor.insertSpaces" = true;
          "editor.formatOnPaste" = true;
          "editor.formatOnSave" = true;
          "editor.renderWhitespace" = "boundary";
          "editor.wordWrapColumn" = 80;
          "editor.wordWrap" = "off";
          "editor.detectIndentation" = true;
          "editor.rulers" = [
            80
          ];
          "files.associations" = {
            "*.inc" = "php";
            "*.module" = "php";
            "*.install" = "php";
            "*.theme" = "php";
            "*.profile" = "php";
            "*.tpl.php" = "php";
            "*.test" = "php";
            "*.php" = "php";
            "*.info" = "ini";
          };
          "files.trimTrailingWhitespace" = true;
          "files.restoreUndoStack" = false;
          "files.insertFinalNewline" = true;
          "html.format.enable" = true;
          "html.format.wrapLineLength" = 80;

          /* PHP Intelephense (bmewburn.vscode-intelephense-client) */
          "intelephense.environment.includePaths" = [
            "core/"
            "core/includes"
            "../vendor/"
          ];

          # Linting
          # https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code#s-linting
          "phpsab.snifferEnable" = true;
          "phpsab.standard" = "Drupal,DrupalPractice";
          "phpsab.snifferArguments" = [ "--extensions=inc,theme,install,module,profile,php,phtml" ];

          # Formatting
          # https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code#s-formatting
          "phpsab.fixerEnable" = true;
          "phpsab.fixerArguments" = [ "--extensions=inc,theme,install,module,profile,php,phtml" ];
          "[php]" = {
            "editor.defaultFormatter" = "valeryanm.vscode-phpsab";
          };

          # PHP validation
          # The settings from this section of the documentation are shown
          # in VSCode as 'Unknown Configuration Setting', therefore they
          # are not included here.
          # https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code#s-php-validation 
        };
      };

  };

  config =
    let
      toPrettyJSON = path: obj: pkgs.runCommand "${path}" { } ''
        ${pkgs.jq}/bin/jq << 'EOF' > $out
          ${builtins.toJSON obj}
        EOF
      '';

      launchPath = "${cfg.vscodeConfigPath}/launch.json";
      launchJson = toPrettyJSON "launch.json" cfg.launch;

      extensionsPath = "${cfg.vscodeConfigPath}/extensions.json";
      extensionsJson = toPrettyJSON "extensions.json" cfg.extensions;

      settingsPath = "${cfg.vscodeConfigPath}/settings.json";
      settingsJson = toPrettyJSON "settings.json" cfg.settings;

      # Function that symlinks a file in the local repo to a Nix derivation.
      # Moves any local configuration out of the way.
      dotFileWriter = localPath: derivPath: ''
        if [ -f "${localPath}" ]; then
          if [ ! -L "${localPath}" ]; then
            echo 'Warning: "${localPath}" already exists, moving it to "${localPath}-before-devenv"'
            mv "${localPath}" "${localPath}-before-devenv"
            ln -s "${derivPath}" "${localPath}"
          elif [ ! "$(readlink ${localPath})" -ef "${derivPath}" ]; then
            rm "${localPath}"
            ln -s "${derivPath}" "${localPath}"
          fi
        else
          ln -s "${derivPath}" "${localPath}"
        fi
      '';
    in
    lib.mkIf (cfg.enable && config.drupal.enable) {
      enterShell = ''
        # VSCode setup.
        mkdir -p ${cfg.vscodeConfigPath}

        ${dotFileWriter launchPath launchJson}
        ${dotFileWriter extensionsPath extensionsJson}
        ${dotFileWriter settingsPath settingsJson}

        if [ -f .gitignore ] && grep -q '.vscode' .gitignore; then
          echo
          echo "Since your VSCode configuration for this project is being managed by Devenv and Nix, adding '.vscode' to your .gitignore file is highly recommended"
          echo
          echo "You can add .vscode to your .gitignore like this:"
          echo '  echo ".vscode" >> .gitignore'
          echo
        fi
      '';
    };

}
