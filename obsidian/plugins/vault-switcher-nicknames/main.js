'use strict';

const { FuzzySuggestModal, Notice, Plugin } = require('obsidian');
const fs = require('fs');
const path = require('path');

const TARGET_COMMAND = 'app:open-another-vault';
const NICKNAME_FILE = ['.obsidian', 'plugins', 'vault-nickname', 'data-shared.json'];

function ipc() {
	if (window.electron && window.electron.ipcRenderer) return window.electron.ipcRenderer;
	return require('electron').ipcRenderer;
}

// Vault Nickname이 각 보관함 폴더에 저장해 둔 표시명. 없으면 상위 폴더명(폴더명은 전부 docs라 무의미).
function displayName(vaultPath) {
	try {
		const raw = fs.readFileSync(path.join(vaultPath, ...NICKNAME_FILE), 'utf8');
		const nickname = JSON.parse(raw).nickname;
		if (typeof nickname === 'string' && nickname.trim() !== '') return nickname.trim();
	} catch (e) {
		// 닉네임 파일이 없거나 깨진 보관함은 조용히 폴더명으로 넘어간다.
	}
	const parent = path.basename(path.dirname(vaultPath));
	return parent !== '' ? parent : path.basename(vaultPath);
}

class VaultSwitcherModal extends FuzzySuggestModal {
	constructor(app) {
		super(app);
		this.setPlaceholder('보관함 열기...');
		this.setInstructions([
			{ command: '↑↓', purpose: '이동' },
			{ command: '↵', purpose: '새 창으로 열기' },
			{ command: 'esc', purpose: '닫기' },
		]);

		// 모달은 열 때마다 새로 만들어지므로 여기서 한 번만 읽는다(입력할 때마다 파일을 읽지 않도록).
		const currentPath = ipc().sendSync('vault').path;
		const vaults = Object.values(ipc().sendSync('vault-list') || {});
		this.items = vaults
			.sort((a, b) => (b.ts || 0) - (a.ts || 0))
			.map((vault) => ({
				path: vault.path,
				name: displayName(vault.path),
				isCurrentVault: vault.path === currentPath,
			}));
	}

	getItems() {
		return this.items;
	}

	getItemText(item) {
		return item.name;
	}

	renderSuggestion(match, el) {
		super.renderSuggestion(match, el);
		if (match.item.isCurrentVault) el.createSpan({ cls: 'flair mod-pop', text: '현재 활성' });
	}

	onChooseItem(item) {
		if (item.isCurrentVault) return;
		if (ipc().sendSync('vault-open', item.path, false) !== true) {
			new Notice('보관함을 열지 못했습니다: ' + item.path);
		}
	}
}

module.exports = class VaultSwitcherNicknamesPlugin extends Plugin {
	onload() {
		const command = this.app.commands.commands[TARGET_COMMAND];
		if (!command) {
			new Notice('Vault Switcher Nicknames: "' + TARGET_COMMAND + '" 명령을 찾지 못했습니다.');
			return;
		}
		this.patchedCommand = command;
		this.originalCallback = command.callback;
		command.callback = () => new VaultSwitcherModal(this.app).open();
	}

	onunload() {
		if (this.patchedCommand && this.originalCallback) {
			this.patchedCommand.callback = this.originalCallback;
		}
	}
};
