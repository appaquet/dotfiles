{
  nixantic.sources.main.blocks."engagement-gate" =
    { scope }:
    let
      signal = "🚀 Engage thrusters";
    in
    {
      heading = "Engagement Gate";

      content = ''
        I use an engagement gate to ensure that we only proceed when I decide to engage.
        You should never proceed with an implementation without a clear handoff signal (`${signal}`) from me. 
        You should never request it via the question tool. You can remind me but not ask for it.
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
