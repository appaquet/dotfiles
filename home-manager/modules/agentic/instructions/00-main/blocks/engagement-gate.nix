{
  nixantic.sources.main.blocks."engagement-gate" =
    { scope }:
    let
      signal = "🚀 Engage thrusters";
    in
    {
      heading = "Engagement Gate";

      content = ''
        Some workflows use an engagement gate that requires the exact handoff signal before proceeding with approved execution. Follow the gate instruction when presented. Do not bypass it.
      '';

      inherit signal;

      gate = ''
        **STOP**: Await for `${signal}` from user before proceeding.
      '';

      release = ''
        Proceed: ${signal}
      '';
    };
}
