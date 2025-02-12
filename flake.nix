{
  description = "Example configurations";
  outputs =
    { ... }:
    {
      templates = {
        default = {
          path = ./example;
          welcomeText = ''
            # Welcome
            This message supports *markdown*!

            ```sh
              echo Hello World
            ```
          '';
        };
      };
    };
}
