{ ... }:

let
  thinkingLevelMap = {
    minimal = "low";
    low = "low";
    medium = "medium";
    high = "xhigh";
    xhigh = "xhigh";
    max = "xhigh";
  };

  mkLocalModel =
    model:
    {
      reasoning = true;
      input = [ "text" ];
      maxTokens = 15000;
      inherit thinkingLevelMap;
      cost = {
        input = 0;
        output = 0;
        cacheRead = 0;
        cacheWrite = 0;
      };
    }
    // model;

  models = {
    providers.deskapp = {
      baseUrl = "http://deskapp.n3x.net:15000/v1";
      api = "openai-completions";
      apiKey = "local";
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        thinkingFormat = "chat-template";
        chatTemplateKwargs = {
          enable_thinking = {
            "$var" = "thinking.enabled";
          };
          reasoning_effort = {
            "$var" = "thinking.effort";
          };
          preserve_thinking = true;
        };
      };
      models = [
        (mkLocalModel {
          id = "qwen3.8-27b";
          name = "qwen3.8-27b (deskapp)";
          contextWindow = 185000;
          samplingParams = {
            temperature = 1.0;
            top_p = 0.95;
            top_k = 20;
            presence_penalty = 0.0;
            repetition_penalty = 1.0;
          };
        })
        (mkLocalModel {
          id = "ornith-1.5-35b";
          name = "Ornith-1.5-35B (deskapp)";
          contextWindow = 262144;
        })
      ];
    };
  };
in
{
  programs.pi.coding-agent.settings = {
    defaultProvider = "scoped";
    defaultModel = "main";
    defaultThinkingLevel = "medium";

    scopeProvider = {
      local = {
        main = {
          model = "deskapp/qwen3.8-27b";
          thinking = "medium";
        };
        remap = {
          "scoped/junior" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "off";
          };
          "scoped/mid" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "low";
          };
          "scoped/senior" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "medium";
          };
          "scoped/staff" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "xhigh";
          };
          "scoped/principal" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "xhigh";
          };
        };
      };
      codex = {
        main = {
          model = "openai-codex/gpt-5.6-sol";
          thinking = "medium";
        };
        remap = {
          "scoped/junior" = {
            model = "openai-codex/gpt-5.6-luna";
          };
          "scoped/mid" = {
            model = "openai-codex/gpt-5.6-luna";
          };
          "scoped/senior" = {
            model = "openai-codex/gpt-5.6-terra";
          };
          "scoped/staff" = {
            model = "openai-codex/gpt-5.6-sol";
          };
          "scoped/principal" = {
            model = "openai-codex/gpt-5.6-sol";
          };
        };
      };
    };
  };

  home.file.".pi/agent/models.json".text = builtins.toJSON models;
}
