// ==UserScript==
// @name         dsh web 手机端适配 (dsh mobile adaptation)
// @namespace    https://github.com/cokelaoshi1/android-termux-dsh
// @version      0.1.0
// @description  为手机浏览器里的 dsh web (127.0.0.1:3080) 注入移动端样式：单列布局、收起右侧面板、触控优化
// @match        http://127.0.0.1:3080/*
// @match        http://localhost:3080/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // 注意：与 mobile/mobile.css 保持同步（这是内嵌版，离线可用）
  var CSS = `
@media (max-width: 900px) {
  [class$="_frame"] { grid-template-columns: 100% !important; }
  [class$="_detailsCol"] { display: none !important; }
  [class$="_sidebarCol"] { width: auto !important; min-width: 0 !important; }
  [class$="_button"], [class$="_trigger"], [class$="_cell"], [class$="_close"] { min-height: 40px; }
  pre, code, [class$="_code"] { white-space: pre-wrap !important; word-break: break-all !important; }
  textarea, input { font-size: 16px !important; }
}
@media (max-width: 480px) {
  [class$="_panel"] { width: 100vw !important; max-width: 100vw !important; height: 100vh !important; max-height: 100vh !important; border-radius: 0 !important; }
}
`;

  var ID = 'dsh-mobile-css';

  function inject() {
    if (document.getElementById(ID)) return;
    var tag = document.createElement('style');
    tag.id = ID;
    tag.textContent = CSS;
    (document.head || document.documentElement).appendChild(tag);

    // 放开缩放：默认 viewport 是 user-scalable=no
    var vp = document.querySelector('meta[name=viewport]');
    if (vp) vp.setAttribute('content', 'width=device-width, initial-scale=1');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }
})();
