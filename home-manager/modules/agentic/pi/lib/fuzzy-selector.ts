import type {
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Container,
  fuzzyFilter,
  Input,
  Spacer,
  Text,
  type KeybindingsManager,
  type TUI,
} from "@earendil-works/pi-tui";

export type FuzzySelectorItem = {
  value: string;
  label?: string;
  description?: string;
};

/**
 * Interactive fuzzy selector for small extension-owned value lists. It keeps
 * matching generic while exposing only the selected value to command handlers.
 */
export class FuzzySelectorComponent extends Container {
  private readonly searchInput: Input;
  private readonly listContainer: Container;
  private readonly tui: TUI;
  private readonly theme: Theme;
  private readonly keybindings: KeybindingsManager;
  private readonly items: readonly FuzzySelectorItem[];
  private readonly done: (value: string | undefined) => void;
  private filteredItems: FuzzySelectorItem[];
  private selectedIndex = 0;
  private closed = false;
  private _focused = false;

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.searchInput.focused = value;
  }

  constructor(
    tui: TUI,
    theme: Theme,
    keybindings: KeybindingsManager,
    title: string,
    items: readonly FuzzySelectorItem[],
    initialSearchInput: string,
    done: (value: string | undefined) => void,
  ) {
    super();
    this.tui = tui;
    this.theme = theme;
    this.keybindings = keybindings;
    this.items = items;
    this.done = done;
    this.filteredItems = filterFuzzyItems(items, initialSearchInput);

    this.addChild(new Text(theme.bold(title), 0, 0));
    this.addChild(new Spacer(1));

    this.searchInput = new Input();
    this.searchInput.setValue(initialSearchInput);
    this.searchInput.onSubmit = () => this.confirm();
    this.searchInput.onEscape = () => this.cancel();
    this.addChild(this.searchInput);
    this.addChild(new Spacer(1));

    this.listContainer = new Container();
    this.addChild(this.listContainer);
    this.addChild(new Spacer(1));
    this.addChild(
      new Text(
        theme.fg("dim", "  Enter to select · Esc to cancel"),
        0,
        0,
      ),
    );

    this.updateList();
  }

  handleInput(keyData: string): void {
    if (this.keybindings.matches(keyData, "tui.select.up")) {
      this.moveSelection(-1);
      return;
    }

    if (this.keybindings.matches(keyData, "tui.select.down")) {
      this.moveSelection(1);
      return;
    }

    if (this.keybindings.matches(keyData, "tui.select.confirm")) {
      this.confirm();
      return;
    }

    if (this.keybindings.matches(keyData, "tui.select.cancel")) {
      this.cancel();
      return;
    }

    this.searchInput.handleInput(keyData);
    this.filteredItems = filterFuzzyItems(
      this.items,
      this.searchInput.getValue(),
    );
    this.selectedIndex = 0;
    this.updateList();
    this.tui.requestRender();
  }

  dispose(): void {
    this.closed = true;
  }

  private moveSelection(offset: number): void {
    if (this.filteredItems.length === 0) return;

    this.selectedIndex =
      (this.selectedIndex + offset + this.filteredItems.length) %
      this.filteredItems.length;
    this.updateList();
    this.tui.requestRender();
  }

  private confirm(): void {
    const selected = this.filteredItems[this.selectedIndex];
    if (!selected || this.closed) return;

    this.closed = true;
    this.done(selected.value);
  }

  private cancel(): void {
    if (this.closed) return;

    this.closed = true;
    this.done(undefined);
  }

  private updateList(): void {
    this.listContainer.clear();

    if (this.filteredItems.length === 0) {
      this.listContainer.addChild(
        new Text(this.theme.fg("muted", "  No matching items"), 0, 0),
      );
      return;
    }

    const maxVisible = 10;
    const startIndex = Math.max(
      0,
      Math.min(
        this.selectedIndex - Math.floor(maxVisible / 2),
        this.filteredItems.length - maxVisible,
      ),
    );
    const endIndex = Math.min(
      startIndex + maxVisible,
      this.filteredItems.length,
    );

    for (let index = startIndex; index < endIndex; index += 1) {
      const item = this.filteredItems[index];
      if (!item) continue;

      const label = item.label ?? item.value;
      const prefix = index === this.selectedIndex ? "→ " : "  ";
      const value =
        index === this.selectedIndex
          ? this.theme.fg("accent", label)
          : label;
      const description = item.description
        ? this.theme.fg("muted", ` — ${item.description}`)
        : "";
      this.listContainer.addChild(
        new Text(`${prefix}${value}${description}`, 0, 0),
      );
    }

    if (startIndex > 0 || endIndex < this.filteredItems.length) {
      this.listContainer.addChild(
        new Text(
          this.theme.fg(
            "muted",
            `  (${this.selectedIndex + 1}/${this.filteredItems.length})`,
          ),
          0,
          0,
        ),
      );
    }
  }
}

/**
 * Returns items in Pi's native fuzzy-match order. Empty queries preserve the
 * caller's order so command configuration controls the initial list.
 */
export function filterFuzzyItems(
  items: readonly FuzzySelectorItem[],
  query: string,
): FuzzySelectorItem[] {
  if (!query) return [...items];

  return fuzzyFilter([...items], query, fuzzyItemSearchText);
}

/**
 * Opens a fuzzy selector through the extension custom-UI API. Cancellation is
 * represented by `undefined`, matching Pi's built-in selector conventions.
 */
export function selectFuzzyItem(
  ctx: Pick<ExtensionContext, "ui">,
  title: string,
  items: readonly FuzzySelectorItem[],
  initialSearchInput = "",
): Promise<string | undefined> {
  return ctx.ui.custom<string | undefined>((tui, theme, keybindings, done) =>
    new FuzzySelectorComponent(
      tui,
      theme,
      keybindings,
      title,
      items,
      initialSearchInput,
      done,
    ),
  );
}

function fuzzyItemSearchText(item: FuzzySelectorItem): string {
  const label = item.label && item.label !== item.value ? item.label : "";
  return [item.value, label, item.description ?? ""].filter(Boolean).join(" ");
}
