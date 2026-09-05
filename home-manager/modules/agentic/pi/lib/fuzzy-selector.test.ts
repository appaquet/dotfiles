import { expect, mock, test } from "bun:test";
import { join } from "node:path";
import type { FuzzySelectorItem } from "./fuzzy-selector.ts";

const nodePath = process.env.NODE_PATH?.split(":")[0];
if (!nodePath) throw new Error("NODE_PATH is required to load Pi's TUI package");

const { fuzzyFilter: nativeFuzzyFilter } = await import(
  join(nodePath, "@earendil-works/pi-tui/dist/fuzzy.js")
);

class TestContainer {
  readonly children: unknown[] = [];

  addChild(child: unknown): void {
    this.children.push(child);
  }

  clear(): void {
    this.children.length = 0;
  }
}

class TestInput {
  focused = false;
  onSubmit?: (value: string) => void;
  onEscape?: () => void;
  private value = "";

  getValue(): string {
    return this.value;
  }

  setValue(value: string): void {
    this.value = value;
  }

  handleInput(input: string): void {
    this.value += input;
  }
}

class TestLeaf {
  constructor(..._args: unknown[]) {}
}

mock.module("@earendil-works/pi-tui", () => ({
  Container: TestContainer,
  Input: TestInput,
  Spacer: TestLeaf,
  Text: TestLeaf,
  fuzzyFilter: nativeFuzzyFilter,
}));

const {
  filterFuzzyItems,
  FuzzySelectorComponent,
  selectFuzzyItem,
} = await import("./fuzzy-selector.ts");

const ITEMS: readonly FuzzySelectorItem[] = [
  { value: "builder", label: "Builder", description: "Direct coding" },
  {
    value: "orchestrator",
    label: "Orchestrator",
    description: "Delegate coding",
  },
  { value: "review", label: "Review", description: "Inspect changes" },
];

function createComponent(
  initialSearchInput = "",
  done: (value: string | undefined) => void = () => {},
): InstanceType<typeof FuzzySelectorComponent> {
  const tui = { requestRender: () => {} };
  const theme = {
    fg: (_color: string, text: string) => text,
    bold: (text: string) => text,
  };
  const keybindings = {
    matches: (input: string, action: string) => input === action,
  };

  return new FuzzySelectorComponent(
    tui as any,
    theme as any,
    keybindings as any,
    "Select mode:",
    ITEMS,
    initialSearchInput,
    done,
  );
}

test("filterFuzzyItems preserves exact items and input order for an empty query", () => {
  expect(filterFuzzyItems(ITEMS, "")).toEqual(ITEMS);
});

test("filterFuzzyItems uses native case-insensitive non-prefix ranking", () => {
  expect(filterFuzzyItems(ITEMS, "Bld").map((item) => item.value)).toEqual([
    "builder",
  ]);
  expect(filterFuzzyItems(ITEMS, "dng").map((item) => item.value)).toEqual([
    "orchestrator",
    "builder",
  ]);
});

test("initial search input filters before confirmation", () => {
  const completed: Array<string | undefined> = [];
  const component = createComponent("RCH", (value) => completed.push(value));

  component.handleInput("tui.select.confirm");

  expect(completed).toEqual(["orchestrator"]);
});

test("input edits update filtering and select the best current match", () => {
  const completed: Array<string | undefined> = [];
  const component = createComponent("", (value) => completed.push(value));

  component.handleInput("v");
  component.handleInput("w");
  component.handleInput("tui.select.confirm");

  expect(completed).toEqual(["review"]);
});

test("arrow input changes the selected fuzzy result", () => {
  const completed: Array<string | undefined> = [];
  const component = createComponent("d", (value) => completed.push(value));

  component.handleInput("tui.select.down");
  component.handleInput("tui.select.confirm");

  expect(completed).toEqual(["builder"]);
});

test("Enter with no matches keeps the selector unresolved", () => {
  const completed: Array<string | undefined> = [];
  const component = createComponent("zzz", (value) => completed.push(value));

  component.handleInput("tui.select.confirm");

  expect(completed).toEqual([]);
});

test("cancel resolves undefined", () => {
  const completed: Array<string | undefined> = [];
  const component = createComponent("", (value) => completed.push(value));

  component.handleInput("tui.select.cancel");

  expect(completed).toEqual([undefined]);
});

test("selectFuzzyItem forwards the selector contract to custom UI", async () => {
  let factoryResult: unknown;
  const ctx = {
    ui: {
      custom: async (factory: (...args: any[]) => unknown) => {
        factoryResult = factory(
          { requestRender: () => {} },
          {
            fg: (_color: string, text: string) => text,
            bold: (text: string) => text,
          },
          { matches: () => false },
          () => {},
        );
        return "builder";
      },
    },
  };

  await expect(
    selectFuzzyItem(ctx as any, "Select mode:", ITEMS, "bld"),
  ).resolves.toBe("builder");
  expect(factoryResult).toBeInstanceOf(FuzzySelectorComponent);
});
