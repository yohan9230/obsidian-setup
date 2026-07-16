'use strict';

const { Notice, Plugin } = require('obsidian');

const TOC_FILE = '목록.md';
// 오른쪽 탭에 열 문서. 단축키 문서는 이 설정을 받은 모든 볼트에 항상 따라오므로
// 어디서든 확실히 열린다. (README 는 새 볼트에 없어서 폴백으로 빠지곤 했다.)
const PREFERRED_FIRST_FILE = 'Obsidian-단축키.md';
const TARGET_PANE_SET_COMMAND = 'target-pane:set';

module.exports = class FirstRunLayoutPlugin extends Plugin {
	onload() {
		this.addCommand({
			id: 'build',
			name: '첫 화면 레이아웃 만들기',
			callback: () => this.buildLayout(),
		});

		// 레이아웃이 다 뜬 뒤에 판단해야 한다. 이 시점이면 target-pane도 로드가 끝나 있다.
		this.app.workspace.onLayoutReady(() => {
			if (this.isBlank()) this.buildLayout();
		});
	}

	// 열린 문서가 하나도 없는 상태(workspace.json이 없는 첫 실행 등).
	isBlank() {
		let hasOpenFile = false;
		this.app.workspace.iterateRootLeaves((leaf) => {
			if (leaf.view && leaf.view.getViewType() !== 'empty') hasOpenFile = true;
		});
		return !hasOpenFile;
	}

	// 보관함 최상위의 문서들. 폴더 안은 목차·첫 문서 후보가 아니다.
	rootNotes() {
		return this.app.vault
			.getMarkdownFiles()
			.filter((file) => file.parent && file.parent.isRoot())
			.sort((a, b) => a.name.localeCompare(b.name, 'ko'));
	}

	async buildLayout() {
		const notes = this.rootNotes();
		const toc = notes.find((file) => file.name === TOC_FILE) || null;
		const others = notes.filter((file) => file !== toc);
		const first = others.find((file) => file.name === PREFERRED_FIRST_FILE) || others[0] || null;

		if (!toc && !first) {
			new Notice('First Run Layout: 보관함 최상위에 열 문서가 없습니다.');
			return;
		}

		// 목차나 첫 문서 중 하나만 있으면 창을 쪼개지 않고 그것만 연다.
		const leftLeaf = this.app.workspace.getLeaf(false);
		if (toc) await leftLeaf.openFile(toc);

		let activeLeaf = leftLeaf;
		if (first) {
			activeLeaf = toc ? this.app.workspace.createLeafBySplit(leftLeaf, 'vertical') : leftLeaf;
			await activeLeaf.openFile(first);
		}

		// target-pane:set은 "가장 최근 창"을 대상으로 잡으므로 오른쪽 창을 활성화한 뒤 부른다.
		this.app.workspace.setActiveLeaf(activeLeaf, { focus: true });
		if (first && !this.app.commands.executeCommandById(TARGET_PANE_SET_COMMAND)) {
			new Notice('First Run Layout: Target Pane 플러그인이 꺼져 있어 대상 창을 지정하지 못했습니다.');
		}
	}
};
