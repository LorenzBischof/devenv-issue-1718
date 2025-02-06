# Drupal development environments in minutes, using Devenv and Nix!

No hassle, no haggle, no Docker.

## Introduction

[Devenv](https://devenv.sh) gives us powerful tools for making PHP development environments, even so, configuring a _Drupal_ development environment on top of this still requires a lot of work. This project aims to provide that configuration, and close the gap between Nix + Devenv and ddev (which provides a Just Works™ developer experience for Drupal).

## What's included

- MySQL, php-fpm, caddy stack pre-configured for Drupal projects.
- Drupal tools like `drush` and `composer`, with tab-completion, and no container in-between you and the tool.
- `mysql` client pre-configured with the correct database details.
- SSL support.
- No messing with ports, projects use https://<PROJECT DIRECTORY>.localhost (and this is configurable).
- Auto-configuration of Drupal's `settings.php`.
- Handy scripts for common tasks, like clearing caches, and importing SQL files.

## Instructions

This assumes Devenv is installed, if it's not, see: [Devenv Getting Started instructions](https://devenv.sh/getting-started/).

Once you have installed Devenv and done the _Initial set up_ step, add this to the `inputs` in `devenv.yaml`:

```yaml
drupal:
  url: gitlab:woolwichweb/drupal-devenv
  flake: false
```

[Inputs documentation](https://devenv.sh/inputs/)

Then add to the `imports` section of `devenv.yaml`:

```yaml
imports:
  - drupal
```

It's likely the `imports` section will not be in the `devenv.yaml` file already, and will need to be created. Also, see [Imports documentation](https://devenv.sh/composing-using-imports/)

For example, a complete `devenv.yaml` with Drupal devenv might look like:

```devenv.yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  drupal:
    url: gitlab:woolwichweb/drupal-devenv
    flake: false

imports:
  - drupal
```

Then add the following to `devenv.nix`:

```nix
  drupal.enable = true;

  # Optional. Remove if you don't use VS Code, or do not want it to be
  # configured for you.
  drupal.vscodeIntegration.enable = true;
```

`vscodeIntegration` configures VS Code according to [Drupal best practices](https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code). Since not everyone uses VS Code and the integration overrides workspace settings, this is optional.
