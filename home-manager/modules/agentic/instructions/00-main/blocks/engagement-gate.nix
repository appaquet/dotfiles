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
        **STOP**: Await for engagement signal `${signal}` before proceeding. Do not ask the user for this signal or approval through a question tool. The user will engage the gate when ready.
      '';

      release = ''
        Proceed: ${signal}
      '';
    };
}
