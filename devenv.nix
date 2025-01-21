{ pkgs
, lib
, config
, ...
}:

let
  cfg = config.drupal;
in
{
  options.drupal = {
    enable = lib.mkEnableOption "tools for Drupal development";

    url = lib.mkOption {
      type = lib.types.str;
      default = (lib.lists.last (lib.path.subpath.components (lib.path.splitRoot (/. + builtins.toPath config.env.DEVENV_ROOT)).subpath)) + ".localhost";
    };

    webRoot = lib.mkOption {
      type = lib.types.str;
      default = "web";
    };

    databaseName = lib.mkOption {
      type = lib.types.str;
      default = "drupal";
    };

    databaseUser = lib.mkOption {
      type = lib.types.str;
      default = "drupal";
    };

    databasePassword = lib.mkOption {
      type = lib.types.str;
      default = "drupal";
    };

    dbDumpDirectory = lib.mkOption {
      type = lib.types.path;
      default = "${config.env.DEVENV_ROOT}/db-init";
    };
  };

  imports = [
    ./vscode-integration.nix
  ];

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.caddy
      pkgs.phpPackages.phpstan
      pkgs.phpPackages.php-codesniffer
    ];

    scripts.cr = {
      exec = ''
        drush cr
      '';
      description = "Rebuild Drupal's caches";
    };

    scripts.crr = {
      exec = ''
        WEBROOT=`[ -z "${cfg.webRoot}" ] || echo "${cfg.webRoot}" | sed 's:/*$::' | sed 's:^./::'`"/"
        while sleep 0.2; do find "$WEBROOT"{modules,themes} -type f | ${pkgs.entr}/bin/entr -s 'drush cr'; done
      '';
      description = "Clear Drupal caches whenever a module or theme file changes";
    };

    scripts.sql-import = {
      exec = ''
        DB_DUMP_PATH="${cfg.dbDumpDirectory}"

        if [ -d "$DB_DUMP_PATH" ]; then
          if [ ! -S "${config.env.DEVENV_RUNTIME}/mysql.sock" ]; then
            echo 'Could not find the MySQL/MariaDB socket file, do you need to run `devenv up`?' >&2
            exit 1
          fi

          if [ $(find "$DB_DUMP_PATH/" -name '*.sql' | wc -l) -eq 0 ]; then
            echo "There aren't any '.sql' files to import in the '$DB_DUMP_PATH' directory"
            exit 0
          fi

          for f in `find "$DB_DUMP_PATH/" -maxdepth 1 -type f -name '*.sql'`; do
            echo "Importing $f"
            if grep --quiet '/\*!999999\\- enable the sandbox mode \*/' "$f"; then
              ${pkgs.pv}/bin/pv "$f" | tail +2 | mysql
            else
              ${pkgs.pv}/bin/pv "$f" | mysql
            fi
          done

        else
          echo "The '$DB_DUMP_PATH' directory does not exist. Please create it and add any SQL files to be imported" >&2
          exit 1
        fi
      '';
      description = "Import all '.sql' files from the '${cfg.dbDumpDirectory}' directory into MariaDB (local)";
    };

    scripts.sql-clean = {
      exec = ''
        DB_DUMP_PATH="${cfg.dbDumpDirectory}"

        if [ -d "$DB_DUMP_PATH" ]; then
            for f in `find "$DB_DUMP_PATH/" -maxdepth 1 -type f -name '*.sql'`; do
              sed -i '/^INSERT INTO `cache/d' "$f";
              sed -i '/^INSERT INTO `search_/d' "$f";
            done
          else
            echo "$DB_DUMP_PATH is not a directory.";
            exit 1
          fi
      '';
      description = "Cleans up a SQL file from a Drupal site. Deletes cache and search index data, which can take up a large portion of a database dump";
    };

    scripts.processes-attach =
      {
        exec = ''
          if [ -S "${config.env.DEVENV_RUNTIME}/pc.sock" ]; then
            process-compose attach --unix-socket=${config.env.DEVENV_RUNTIME}/pc.sock
          else
            echo 'Either the environment hasn't been started or `devenv up` wasn't started in the background' >&2
            exit 1
          fi
        '';
        description = "Connect to a background process-compose (only works if 'devenv up' was started in the background, using 'devenv up -d')";
      };

    languages.php = lib.mkDefault {
      enable = true;
      extensions = [ "xdebug" ];
      version = "8.3";
      fpm.phpOptions = ''
        upload_max_filesize = 1G
        post_max_size = 1G
        memory_limit = 1G
        xdebug.mode = debug
        xdebug.start_with_request = yes
        xdebug.client_host = unix://${config.env.DEVENV_RUNTIME}/xdebug.sock
        xdebug.log = ${config.env.DEVENV_RUNTIME}/xdebug.log
      '';
      fpm.pools = {
        drupal = {
          settings = {
            "pm" = "dynamic";
            "pm.max_children" = 4;
            "pm.min_spare_servers" = 1;
            "pm.max_spare_servers" = 2;
            "pm.start_servers" = 1;
            "pm.max_requests" = 50;
          };
        };
      };
    };

    services.caddy.enable = lib.mkDefault true;

    services.caddy.virtualHosts = lib.mkDefault {
      ${cfg.url} = {
        extraConfig = ''
          encode gzip
          log
          root * ${config.env.DEVENV_ROOT}${if cfg.webRoot != "" then "/${cfg.webRoot}" else "" }
          php_fastcgi unix//${config.languages.php.fpm.pools.drupal.socket}
          file_server

          @hiddenFilesRegexp path_regexp (^|/)\.
          error @hiddenFilesRegexp 403

          @hiddenPhpFilesRegexp path_regexp \..*/.*\.php$
          error @hiddenPhpFilesRegexp 403

          @vendorPhpFiles path /vendor/.*\.php$
          error @vendorPhpFiles 404

          @sitesFilesPhpFilesRegexp path_regexp ^/sites/[^/]+/files/.*\.php$
          error @sitesFilesPhpFilesRegexp 404

          @privateDirRegexp path_regexp ^/sites/.*/private/
          error @privateDirRegexp 403

          @protectedFilesRegexp {
            path_regexp \.(engine|inc|install|make|module|profile|po|sh|.*sql|theme|twig|tpl(\.php)?|xtmpl|yml)(~|\.sw[op]|\.bak|\.orig|\.save)?$|^(Entries.*|Repository|Root|Tag|Template|composer\.(json|lock)|web\.config)$|^#.*#$|\.php(~|\.sw[op]|\.bak|\.orig|\.save)$
          }
          error @protectedFilesRegexp 404

          @staticFiles path_regexp \.(avif|css|eot|gif|gz|ico|jpg|jpeg|js|otf|pdf|png|svg|ttf|webp|woff|woff2)
          header @staticFiles Cache-Control "max-age=31536000,public,immutable"

          @privateFiles path_regexp ^(/[a-z\-]+)?/system/files/
          handle @privateFiles {
            try_files {path} /index.php?{query}
          }
        '';
      };
    };

    services.caddy.config = lib.mkDefault ''
      {
        skip_install_trust
      }
    '';

    services.mysql = lib.mkDefault {
      enable = true;
      initialDatabases = [{ name = "${cfg.databaseName}"; }];
      ensureUsers = [
        {
          name = "${cfg.databaseUser}";
          password = "${cfg.databasePassword}";
          ensurePermissions = {
            "${cfg.databaseName}.*" = "ALL PRIVILEGES";
          };
        }
      ];

      # For convenience, set the details needed for the client to connect to the
      # database. This makes it possible to get into the db by running `mysql`
      # with no args.
      useDefaultsExtraFile = true;
      settings = {
        mysqld = {
          skip-networking = true;
        };
        client = {
          user = cfg.databaseUser;
          password = cfg.databasePassword;
          database = cfg.databaseName;
          socket = "${config.env.DEVENV_RUNTIME}/mysql.sock";
        };
        mysqldump = {
          quick = true;
        };
      };
    };

    enterShell = ''
      export PATH="${builtins.dirOf config.scripts.mysql.exec}:$PATH:${config.env.DEVENV_ROOT}/vendor/bin"
      export DRUSH_OPTIONS_URI="https://${cfg.url}"
      export WEBROOT=`[ -z "${cfg.webRoot}" ] || echo "${cfg.webRoot}" | sed 's:/*$::' | sed 's:^./::'`"/"

      # Workaround 'complete: command not found' error.
      export BASH_COMPLETION_USER_DIR="${config.env.DEVENV_DOTFILE}/bash-completions"

      export MYSQL_HISTFILE="${config.env.DEVENV_STATE}/mysql_history"

      # Share state between instances of Caddy. This is crucial for stopping
      # conflicts when working on multiple projects.
      if [ ! -L "${config.env.DEVENV_STATE}/caddy" ]; then
        caddy_dirs=(
          "$HOME/.local/share/caddy"
          "$HOME/Library/Application Support/Caddy"
          "$HOME/lib/caddy"
          "$HOME/caddy"
        )

        for caddy_dir in "''${caddy_dirs[@]}"; do
          if [ -d "$caddy_dir" ]; then
            # Fix 'Failed to create symbolic link' error on enterShell,
            # when the state dir hasn't been created yet.
            mkdir -p "${config.env.DEVENV_STATE}"
            ln -s "$caddy_dir" "${config.env.DEVENV_STATE}/caddy"
            break
          fi
        done
      fi

      chmod +w "$WEBROOT"sites/default

      # @TODO: MAJOR TODO, IMPORTANT! Instead of this, generate a
      # settings.devenv.php file that's in a Nix derivation and link it into
      # settings.php. That will fix multiple bugs, like passwords not being
      # updated, and make this more idiomatic Nix.

      # Ensure settings.local.php exists and has the correct database config.
      if [ ! -f "$WEBROOT"sites/default/settings.local.php ]; then
        # Example local settings file is created by Composer, if it hasn't
        # been run yet, the file might not yet exist, so just create an
        # empty file.
        if [ -f "$WEBROOT"sites/example.settings.local.php ]; then
          cp "$WEBROOT"sites/example.settings.local.php web/sites/default/settings.local.php
        else
          echo '<?php' > "$WEBROOT"sites/default/settings.local.php
        fi
      fi

      if ! grep -q "\$databases\['default'\]\['default'\] =" "$WEBROOT"sites/default/settings.local.php; then
        cat >> "$WEBROOT"sites/default/settings.local.php <<EOF

      \$databases['default']['default'] = [
        'database' => '${cfg.databaseName}',
        'username' => '${cfg.databaseUser}',
        'password' => '${cfg.databasePassword}',
        'unix_socket' => ''',
        'driver' => 'mysql',
        'prefix' => ''',
      ];
      EOF
      fi
      sed --in-place "s#'unix_socket' => '[^'\n]*',#'unix_socket' => '${config.env.DEVENV_RUNTIME}/mysql.sock',#" "$WEBROOT"sites/default/settings.local.php

      if grep -q "^\$settings\['hash_salt'\] = '''" "$WEBROOT"sites/default/settings.php; then
        SALT=`head -c 55 /dev/urandom | base64`
        sed --in-place "s#\$settings\['hash_salt'\] = '''#\$settings['hash_salt'] = '$SALT'#" "$WEBROOT"sites/default/settings.php
      elif ! grep -q "^\$settings\['hash_salt'\] =" "$WEBROOT"sites/default/settings.php && ! grep -Eq "^\\\$drupal_hash_salt = '[^'\s]+'" "$WEBROOT"sites/default/settings.php; then
        SALT=`head -c 55 /dev/urandom | base64`
        cat >> "$WEBROOT"sites/default/settings.php <<EOF
      \$settings['hash_salt'] = '$SALT';
      EOF
      fi

      if ! sed "s:\(.*\)\(//\|#\).*:\1:g" "$WEBROOT"sites/default/settings.php | grep -Eq "include[^\n]+/settings.local.php"; then
        cat >> "$WEBROOT"sites/default/settings.php <<EOF

      if (file_exists(\$app_root . '/' . \$site_path . '/settings.local.php')) {
        include \$app_root . '/' . \$site_path . '/settings.local.php';
      }
      EOF
      fi

      mkdir -p "${config.env.DEVENV_DOTFILE}/bash-completions/completions"
      if [ ! -f "${config.env.DEVENV_DOTFILE}/bash-completions/completions/drush" ]; then
        drush completion > "${config.env.DEVENV_DOTFILE}/bash-completions/completions/drush"
      fi

      if [ ! -f "${config.env.DEVENV_DOTFILE}/bash-completions/completions/composer" ]; then
        composer completion bash > "${config.env.DEVENV_DOTFILE}/bash-completions/completions/composer"
      fi

      if command -v terminus 2>&1 >/dev/null; then
        if [ ! -f "${config.env.DEVENV_DOTFILE}/bash-completions/completions/terminus" ]; then
          terminus completion > "${config.env.DEVENV_DOTFILE}/bash-completions/completions/terminus"
        fi
      fi

      if command -v platform 2>&1 >/dev/null; then
        if [ ! -f "${config.env.DEVENV_DOTFILE}/bash-completions/completions/platform" ]; then
          platform completion > "${config.env.DEVENV_DOTFILE}/bash-completions/completions/platform"
        fi
      fi

      # If this prompts obnoxiously often (due to updates), it could be changed to:
      # sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
      # See: https://github.com/cachix/devenv/issues/553
      if ! getcap ${pkgs.caddy}/bin/caddy | grep -q 'cap_net_bind_service=ep'; then
        echo
        echo "Setting up Caddy, you may be asked for your sudo password"
        echo
        sudo setcap cap_net_bind_service=+ep ${pkgs.caddy}/bin/caddy

        # Assume that caddy certs only need to be installed at the same time
        # port capability is created.
        # Start Caddy
        caddy start
        # Talk to started Caddy, setup certificate trust
        caddy trust
        # Stop Caddy (the user will start it with `devenv up`)
        caddy stop
      fi
    '';
  };
}
