function forEach(arr, fn) {
	var i;
	for (i = 0; i < arr.length; ++i)
		fn.apply(arr[i]);
}
function selectNavTab(nav, tab) {
	tab = '#' + tab;
	forEach (nav.getElementsByTagName("a"), function() {
		this.className = this.hash == tab ? this.className + ' current '
			: this.className.replace(' current ', '');
	})
}
function onload() {
	forEach (configure_nav.getElementsByTagName("a"), function() {
		this.tabIndex = 1000;
		if (this.hash != "") {
			this.onclick = function() {
				if (event.preventDefault)
					event.preventDefault(); // IE11
				event.returnValue =  // IE8/IE6
				switchPage(this.hash.substr(1));
			}
		}
	})
}
function initOptions(curName, curVer, curType, newVer, instDir, smFolder, defType, is64) {
	if (onload) onload(), onload = null;
	var opt;
	var warn;
	var types = {Unicode: "Unicode 32-bit", ANSI: "ANSI 32-bit", x64: "Unicode 64-bit"};
	var curTypeName = types[curType];
	var defTypeName = types[defType];
	curTypeName = curTypeName ? " (" + curTypeName + ")" : "";
	if (curName == "AutoHotkey" && curVer <= "1.0.48.05") {
		start_intro.innerText = curName + " v" + curVer + " is installed. What do you want to do?";
		var uniType = is64 ? "x64" : "Unicode";
		var uniTypeName = types[uniType];
		opt = [
			"AHK('Upgrade', 'ANSI')", "Upgrade to v" + newVer + " (" + types.ANSI + ")", "Recommended for compatibility.",
			"AHK('Upgrade', '" + uniType + "')", "Upgrade to v" + newVer + " (" + uniTypeName + ")", "",
			"AHK('Customize')", "Custom Installation", ""
		];
		warn = '<strong>Note:</strong> Some AutoHotkey 1.0 scripts are <a href="#" onclick="'+"AHK('ViewHelp', '/docs/Compat.htm'); return false"+'">not compatible</a> with AutoHotkey 1.1.';
	} else if (curName == "") {
		start_intro.innerText = "Please select the type of installation you wish to perform.";
		opt = [
			"AHK('QuickInstall')", "Express Installation", "Default version: " + defTypeName + "<br>Install in: " + instDir,
			"AHK('Customize')", "Custom Installation", ""
		];
	} else if (curVer != newVer) {
		start_intro.innerText = curName + " v" + curVer + curTypeName + " is installed. What do you want to do?";
		opt = [
			"AHK('Upgrade', '" + defType + "')", (curVer < newVer ? "Upgrade" : "Downgrade") + " to v" + newVer + " (" + defTypeName + ")", "",
			"AHK('Customize')", "Custom Installation", ""
		];
	} else {
		start_intro.innerText = curName + " v" + curVer + curTypeName + " is installed. What do you want to do?";
		opt = [
			"AHK('QuickInstall')", "Repair", "",
			"AHK('Customize')", "Modify", "",
			"AHK('Uninstall')", "Uninstall", ""
		];
	}
	var i, html = [];
	for (i = 0; i < opt.length; i += 3) {
		html.push('<a href="#" onclick="', opt[i], '; return false" id="opt', Math.floor(i/3)+1, '"><span>', opt[i+1], '</span>');
		if (opt[i+2])
			html.push('<p>', opt[i+2], '</p>');
		if (opt[i] == "AHK('Customize')")
			html.push('<div class="marker">\u00BB</div>');
		html.push('</a>');
	}
	start_options.innerHTML = html.join("");
	start_warning.innerHTML = warn;
	start_warning.style.display = warn ? "block" : "none";
	version_number.innerHTML = 'version ' + newVer;
	installtype.value = defType;
	installdir.value = instDir;
	startmenu.value = smFolder;
	startmenu.onblur();
	forEach (document.getElementsByTagName("a"), function() {
		if (/*this.className == "button" ||*/ this.parentNode.className == "options")
			this.hideFocus = true;
	})
}
document.onselectstart =
document.oncontextmenu =
document.ondragstart =
	function() {
		return window.event && event.srcElement.tagName == "INPUT" || false;
	};
function setInstallType(type) {
	installtype.value = type;
	switchPage(configureMode ? 'options' : 'location');
	event.returnValue = false;
}
function switchPage(page) {
	page = document.getElementById(page);
	for (var n = page.parentNode.firstChild; n; n = n.nextSibling) if (n.className == "page") {
		if (n != page)
			n.style.display = "none";
		else
			n.style.display = "block";
	}
	selectNavTab(configure_nav, page.id);
	var f;
	switch (page.id) {
	case "version": f = "it_" + installtype.value; break;
	case "location": f = "next-button"; break;
	case "options": f = "install_button"; break;
	case "done": f = "done_exit"; break;
	}
	if (f) {
		// If page == version, it mightn't actually be visible at this point,
		// which causes IE7 (and perhaps older) to throw error 0x80020101.
		try { document.getElementById(f).focus() } catch (ex) { }
	}
	return false;
}
function customInstall() {
	if (startmenu.style.color)
		startmenu.value = '';
	return AHK('CustomInstall');
}