var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// main.ts
var main_exports = {};
__export(main_exports, {
  default: () => InProgressCheckboxPlugin
});
module.exports = __toCommonJS(main_exports);
var import_obsidian = require("obsidian");
var CHECKBOX_REGEX = /^(\s*[-*+]\s*\[)([^\]])(\])/;
var InProgressCheckboxPlugin = class extends import_obsidian.Plugin {
  onload() {
    this.registerDomEvent(
      document,
      "click",
      (evt) => {
        this.handleCheckboxClick(evt);
      },
      true
    );
  }
  handleCheckboxClick(evt) {
    const target = evt.target;
    const isCheckbox = target.classList.contains("task-list-item-checkbox") || target instanceof HTMLInputElement && target.type === "checkbox";
    if (!isCheckbox) return;
    if (target.closest(".block-language-tasks, .plugin-tasks-query-result")) return;
    const isInMarkdownView = target.closest(
      ".markdown-preview-view, .markdown-reading-view, .cm-content"
    );
    if (!isInMarkdownView) return;
    const view = this.app.workspace.getActiveViewOfType(import_obsidian.MarkdownView);
    if (!(view == null ? void 0 : view.file)) return;
    evt.preventDefault();
    evt.stopPropagation();
    if (view.getMode() === "preview") {
      void this.handleReadingMode(evt, view, target);
    } else if (view.getMode() === "source") {
      this.handleLivePreview(evt, view);
    }
  }
  async handleReadingMode(evt, view, target) {
    const listItem = target.closest("li.task-list-item");
    if (!listItem) return;
    const current = listItem.getAttribute("data-task") || " ";
    const next = evt.shiftKey ? "/" : current === "x" ? " " : "x";
    if (current === next) return;
    const line = await this.findTaskLineNumber(view, listItem);
    if (line !== -1) void this.updateLine(view, line, next);
  }
  handleLivePreview(evt, view) {
    var _a;
    const cm = (_a = view.editor) == null ? void 0 : _a.cm;
    if (!cm) return;
    const pos = cm.posAtCoords({ x: evt.clientX, y: evt.clientY });
    if (pos === null) return;
    const lineInfo = cm.state.doc.lineAt(pos);
    const lineNum = lineInfo.number - 1;
    const match = lineInfo.text.match(CHECKBOX_REGEX);
    if (!match) return;
    const current = match[2];
    const next = evt.shiftKey ? "/" : current === "x" ? " " : "x";
    if (current !== next) void this.updateLine(view, lineNum, next);
  }
  async updateLine(view, lineNum, state) {
    const file = view.file;
    if (!file) return;
    const content = await this.app.vault.read(file);
    const lines = content.split("\n");
    if (!lines[lineNum] || !CHECKBOX_REGEX.test(lines[lineNum])) return;
    lines[lineNum] = lines[lineNum].replace(CHECKBOX_REGEX, `$1${state}$3`);
    await this.app.vault.modify(file, lines.join("\n"));
  }
  async findTaskLineNumber(view, listItem) {
    var _a;
    if (!view.file) return -1;
    const cache = this.app.metadataCache.getFileCache(view.file);
    const taskItems = (_a = cache == null ? void 0 : cache.listItems) == null ? void 0 : _a.filter((i) => i.task !== void 0);
    if (!taskItems || taskItems.length === 0) return -1;
    const content = await this.app.vault.read(view.file);
    const lines = content.split("\n");
    const domText = this.getDirectTextContent(listItem);
    const sortedTasks = [...taskItems].sort(
      (a, b) => a.position.start.line - b.position.start.line
    );
    const candidates = [];
    for (const task of sortedTasks) {
      const lineText = lines[task.position.start.line];
      if (!lineText) continue;
      const match = lineText.match(/^\s*[-*+]\s*\[[^\]]\]\s*(.*)$/);
      if (!match) continue;
      const sourceText = this.normalizeMarkdown(match[1]);
      candidates.push({ line: task.position.start.line, text: sourceText });
      if (sourceText === domText) {
        const exactMatches = sortedTasks.filter((t) => {
          const lt = lines[t.position.start.line];
          const m = lt == null ? void 0 : lt.match(/^\s*[-*+]\s*\[[^\]]\]\s*(.*)$/);
          return m && this.normalizeMarkdown(m[1]) === domText;
        });
        if (exactMatches.length === 1) {
          return task.position.start.line;
        }
      }
    }
    const matchingLines = candidates.filter((c) => c.text === domText);
    if (matchingLines.length > 1) {
      const container = listItem.closest(".markdown-preview-view, .markdown-reading-view");
      if (container) {
        const allTasks = Array.from(container.querySelectorAll("li.task-list-item"));
        let occurrenceIndex = 0;
        for (const task of allTasks) {
          if (task === listItem) break;
          if (this.getDirectTextContent(task) === domText) {
            occurrenceIndex++;
          }
        }
        if (occurrenceIndex < matchingLines.length) {
          return matchingLines[occurrenceIndex].line;
        }
      }
    }
    if (matchingLines.length > 0) {
      return matchingLines[0].line;
    }
    return -1;
  }
  getDirectTextContent(element) {
    var _a;
    const clone = element.cloneNode(true);
    const nested = clone.querySelectorAll("ul, ol");
    for (let i = 0; i < nested.length; i++) {
      nested[i].remove();
    }
    const fullText = ((_a = clone.textContent) == null ? void 0 : _a.trim()) || "";
    return fullText.split("\n")[0].trim();
  }
  normalizeMarkdown(text) {
    return text.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\[\[(?:[^|\]]*\|)?([^\]]*)\]\]/g, "$1").replace(/(\*\*|__|~~|==)(.+?)\1/g, "$2").replace(/(\*|_)(.+?)\1/g, "$2").replace(/`([^`]+)`/g, "$1").replace(/#(\w+)/g, "$1").trim();
  }
};

/* nosourcemap */