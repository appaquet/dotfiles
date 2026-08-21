{ pkgs, lib }:

let
  capabilities = import ../harnesses/pi/capabilities.nix { inherit lib; };
  defaults = capabilities.resolve { };
  overridden = capabilities.resolve {
    agents = "tintinweb";
    tasks = "tintinweb";
    questions = "pi-vault-questionnaire";
  };
  unknownAgent = builtins.tryEval (capabilities.validate { agents = "unknown"; });
  unknownTask = builtins.tryEval (capabilities.validate { tasks = "unknown"; });
  unknownQuestion = builtins.tryEval (capabilities.validate { questions = "unknown"; });

  cases = [
    {
      name = "Pi capability defaults resolve independent adapter selections";
      pass =
        defaults.selections == {
          agents = "tintinweb";
          tasks = "tintinweb";
          questions = "rpiv-ask-user-question";
        }
        &&
          defaults.capabilities.agents == {
            launch = "Agent";
            result = "get_subagent_result";
            steer = "steer_subagent";
          }
        && defaults.capabilities.tasks.create == "TaskCreate"
        && defaults.capabilities.questions == { ask = "ask_user_question"; }
        && defaults.capabilities.skills.invocation == "pi-native"
        &&
          defaults.adapters.agents.supportedPolicyFields == [
            "allowedSubagents"
            "disallowedTools"
            "excludeExtensions"
            "extensions"
            "isolated"
            "isolation"
            "persistSession"
            "skills"
            "tools"
          ]
        && defaults.prose.questions.request == "use `ask_user_question`"
        && lib.hasInfix "Task*" defaults.prose.tasks.workflow;
      detail = "expected the three configured adapters to expose tool capabilities and one-line tool mentions";
    }
    {
      name = "Pi adapter selections remain independent";
      pass =
        overridden.capabilities.agents.launch == "Agent"
        && overridden.capabilities.tasks.create == "TaskCreate"
        && overridden.capabilities.questions.ask == "questionnaire";
      detail = "expected independently selected agent, task, and question adapters to retain their respective capabilities";
    }
    {
      name = "unknown Pi adapter selections fail clearly";
      pass = !unknownAgent.success && !unknownTask.success && !unknownQuestion.success;
      detail = "expected unknown agent, task, and question selections to fail evaluation";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
