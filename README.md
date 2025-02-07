# Drupal development environments in minutes, using Devenv and Nix!

No hassle, no haggle, no Docker¹.

## Introduction

[Devenv](https://devenv.sh) gives us powerful tools for making PHP development environments, even so, configuring a _Drupal_ development environment still requires a lot of work. _drupal-devenv_ aims to do that configuration work, closing the gap between Nix + Devenv and ddev (which provides a Just Works™ developer experience for Drupal).

## What's included

- MySQL, php-fpm, caddy stack pre-configured for Drupal projects.
- Drupal tools like `drush` and `composer`, with tab-completion, and no container in-between you and the tool.
- `mysql` client pre-configured with the correct database details.
- SSL support.
- No messing with ports, projects use `https://<PROJECT DIRECTORY>.localhost` (and this is configurable).
- Auto-configuration of Drupal's `settings.php`.
- Handy scripts for common tasks, like clearing caches, and importing SQL files.
- (VSCode) pre-configured extensions and completely automated setup of XDebug, just hit the Debug tab and click the play button!

## Getting started

1. If you haven't already, [Install Devenv](https://devenv.sh/getting-started/) and complete the _Initial set up_ to initialise Devenv for your project.

   1.1. (optional, recommended) Setup [automatic shell activation](https://devenv.sh/automatic-shell-activation/).

2. Open `devenv.yaml` and add this to `inputs`:

   ```yaml
     drupal:
       url: gitlab:woolwichweb/drupal-devenv
       flake: false
   ```

3. At the bottom of `devenv.yaml`, add the `imports` section:

   ```yaml
   imports:
     - drupal
   ```

5. Add the following to `devenv.nix`:

   ```nix
     drupal.enable = true;

     # Optional. Remove if you don't use VS Code, or do not want it to be
     # configured for you.
    drupal.vscodeIntegration.enable = true;
   ```

6. From the terminal, run `devenv up`

   Or, if you didn't setup [automatic shell activation](https://devenv.sh/automatic-shell-activation/), run `devenv shell` and then `devenv up`.

7. 🚀 Finished!

### `devenv.yaml` example

A complete _drupal-devenv_ enabled `devenv.yaml` should look like this:

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

### `devenv.nix` example

```nix
{ pkgs, lib, config, inputs, ... }:

{
  drupal.enable = true;
  drupal.vscodeIntegration.enable = true;
}
```

A note regarding `drupal.vscodeIntegration`: this configures VSCode according to [Drupal best practices](https://www.drupal.org/docs/develop/development-tools/editors-and-ides/configuring-visual-studio-code). Since not everyone uses VSCode and the integration overrides workspace settings, enabling this is optional.

It's also possible to enable VSCode integration, then disable any undesirable extensions (from inside VSCode).

### See also

- [Inputs documentation](https://devenv.sh/inputs/)
- [Imports documentation](https://devenv.sh/composing-using-imports/)

### Everyday usage

Run `devenv up` to start the services.

Or, if you didn't setup [automatic shell activation](https://devenv.sh/automatic-shell-activation/), run `devenv shell` and then `devenv up`.

Automatic shell activation is highly recommended, it's a really cool feature for automatically switching development environments just by changing directory.

## Customisation

Check the [devenv guide](https://devenv.sh/getting-started/) for instructions on customising your Drupal development environment.

_drupal-devenv_ aims to be composable. It shouldn't stop you customising your environment to your tastes, installing more services, or integrating those services into your Drupal setup.

### Examples

#### Adding an extension

In your `devenv.nix` add the name of the extension. This example adds ImageMagick:

```nix
languages.php.extensions = [ "xdebug" "imagick" ];
```

Note: if your extensions list does not include `"xdebug"` it will not be installed, since _drupal-devenv_ also uses `languages.php.extensions`. This also means you can disable XDebug in your environment, if you don't want it.

#### Switching PHP versions

Add this to your `devenv.nix`:

```nix
languages.php.version = "7.4";
```

#### See also

- For other options, see [Devenv's PHP documentation](https://devenv.sh/supported-languages/php/).
- Find more PHP extensions, and other packages, using [Nix package search](https://search.nixos.org).

## Footnotes

¹ Docker is fine, and Nix works well with it, but why use an extra layer of abstraction if it's not necessary? drupal-devenv aims to provide all the advantages of a Docker-based setup, without the container overhead.