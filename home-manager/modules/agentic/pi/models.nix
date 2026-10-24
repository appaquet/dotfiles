{ ... }:

let
  thinkingLevelMap = {
    off = "none";
    minimal = "low";
    low = "low";
    medium = "medium";
    high = "xhigh";
    xhigh = "xhigh";
    max = "xhigh";
  };

  models = {
    providers.deskapp = {
      baseUrl = "http://deskapp.n3x.net:8080/v1";
      api = "openai-completions";
      apiKey = "local";

      discoverModels = true; # used by `model-discovery` extension to register models from GET /v1/models
      discoverDefaults = {
        contextWindow = 125000;
        maxTokens = 32000;
        input = [
          "text"
        ];
      };

      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = true;
        supportsStrictMode = false;
        thinkingFormat = "openai";
      };

      modelOverrides = {
        "qwen3.8-27b" = {
          contextWindow = 250000;
          maxTokens = 32000;
          input = [
            "text"
            "image"
          ];

          inherit thinkingLevelMap;

          samplingParams = {
            temperature = 1.0;
            top_p = 0.95;
            top_k = 20;
            presence_penalty = 0.0;
            repetition_penalty = 1.0;
          };
        };
      };
    };
  };
in
{
  dotfiles.pi.settings = {
    defaultProvider = "scoped";
    defaultModel = "main";
    defaultThinkingLevel = "medium";

    scopeProvider = {
      local = {
        main = {
          model = "deskapp/qwen3.8-27b";
          thinking = "medium";
        };
        prompt = {
          enable = "Local scope: do not run sub-agents in parallel. At most one at a time.";
          disable = "Local scope ended: sub-agents may run in parallel again.";
        };
        remap = {
          "scoped/junior" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "off";
          };
          "scoped/summary" = {
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
          "scoped/reviewer" = {
            model = "deskapp/qwen3.8-27b";
            thinking = "xhigh";
          };
        };
      };

      codex = {
        main = {
          model = "openai/gpt-6.1-sol";
          thinking = "high";
        };
        remap = {
          "scoped/junior" = {
            model = "opencode-go/deepseek-v4.1-flash";
            thinking = "low";
          };
          "scoped/summary" = {
            model = "openai/gpt-6-luna";
            thinking = "high";
          };
          "scoped/mid" = {
            model = "openai/gpt-6-luna";
            thinking = "high";
          };
          "scoped/senior" = {
            model = "openai/gpt-6.1-sol";
            thinking = "high";
          };
          "scoped/staff" = {
            model = "openai/gpt-6.1-sol";
            thinking = "xhigh";
          };
          "scoped/principal" = {
            model = "openai/gpt-6-astra";
            thinking = "medium";
          };
          "scoped/reviewer" = {
            model = "openai/gpt-6.1-sol";
            thinking = "medium";
          };
        };
      };

      # See docs/features/2026/08/28-pi-opencode-scope for calculation
      go = {
        main = {
          model = "opencode-go/deepseek-v4.1-flash";
          thinking = "high";
        };
        remap = {
          "scoped/junior" = {
            model = "opencode-go/deepseek-v4.1-flash";
            thinking = "low";
          };
          "scoped/summary" = {
            model = "opencode-go/deepseek-v4.1-flash";
            thinking = "low";
          };
          "scoped/mid" = {
            model = "opencode-go/deepseek-v4.1-flash";
            thinking = "high";
          };
          "scoped/senior" = {
            model = "opencode-go/glm-5.3-flash";
            thinking = "medium";
          };
          "scoped/staff" = {
            model = "opencode-go/glm-5.3-flash";
            thinking = "max";
          };
          "scoped/principal" = {
            model = "opencode-go/glm-5.3";
            thinking = "max";
          };
          "scoped/reviewer" = {
            model = "opencode-go/qwen3.8-flash";
            thinking = "high";
          };
        };
      };
    };
  };

  home.file.".pi/agent/models.json".text = builtins.toJSON models;
}
