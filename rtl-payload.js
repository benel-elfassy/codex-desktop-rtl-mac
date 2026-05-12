// ===========================================================================
// Codex RTL Patch - Smart RTL Detection & Alignment
//
// Injected into Codex Desktop renderer bundles by patch.sh.
// Adds automatic Hebrew/Arabic direction handling while preserving LTR code,
// terminal, shell, and diff surfaces.
// ===========================================================================
// --- CODEX RTL PATCH START ---
;(function () {
  'use strict';

  if (typeof document === 'undefined' || window.__CODEX_RTL_PATCH_ACTIVE__) return;
  window.__CODEX_RTL_PATCH_ACTIVE__ = true;

  var STYLE_ID = 'codex-rtl-styles';
  var RTL_SELECTOR =
    'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, summary, label, legend, dt, dd, figcaption, caption';
  var COMPACT_SELECTOR = 'span, button, a, label, div';
  var EDITABLE_SELECTOR = 'textarea, input[type="text"], input:not([type]), [contenteditable="true"], [role="textbox"]';
  var LTR_SELECTOR = [
    'pre',
    'code',
    'kbd',
    'samp',
    '.cm-editor',
    '.cm-line',
    '.monaco-editor',
    '[class*="terminal"]',
    '[class*="xterm"]',
    '[class*="diff"]',
    '[data-language]',
    '[data-testid*="terminal"]',
    '[data-testid*="diff"]',
    '[data-testid*="shell"]',
  ].join(',');

  function isRTLChar(ch) {
    var code = ch.charCodeAt(0);
    return (
      (code >= 0x0590 && code <= 0x05ff) ||
      (code >= 0x0600 && code <= 0x06ff) ||
      (code >= 0x0750 && code <= 0x077f) ||
      (code >= 0x08a0 && code <= 0x08ff)
    );
  }

  function hasRTL(text) {
    if (!text) return false;
    for (var i = 0; i < text.length; i++) {
      if (isRTLChar(text[i])) return true;
    }
    return false;
  }

  function firstStrong(text) {
    if (!text) return null;
    for (var i = 0; i < text.length; i++) {
      if (isRTLChar(text[i])) return 'rtl';
      if (/[A-Za-z]/.test(text[i])) return 'ltr';
    }
    return null;
  }

  function stripLeadingLTR(text) {
    return String(text || '')
      .replace(/^\s*(?:[\w.-]+\.[A-Za-z]{1,8})\s*/g, '')
      .replace(/https?:\/\/\S+/g, '')
      .replace(/[\w.-]+[\\/][\w./-]+/g, '')
      .replace(/`[^`]+`/g, '')
      .replace(/^\s*[$>#]\s+/g, '');
  }

  function detectTextDir(text) {
    if (!text || !String(text).trim()) return null;
    var direct = firstStrong(text);
    if (direct === 'rtl') return 'rtl';
    if (!hasRTL(text)) return 'ltr';
    var stripped = stripLeadingLTR(text);
    direct = firstStrong(stripped);
    return direct === 'ltr' && !hasRTL(stripped) ? 'ltr' : 'rtl';
  }

  function textWithoutCode(el) {
    var out = '';
    var nodes = el.childNodes || [];
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.textContent || '';
      } else if (node.nodeType === Node.ELEMENT_NODE && !isLTRSurface(node)) {
        out += textWithoutCode(node);
      }
    }
    return out;
  }

  function detectElDir(el) {
    var full = el.textContent || '';
    if (!hasRTL(full)) return null;
    return detectTextDir(textWithoutCode(el)) || 'rtl';
  }

  function qsa(root, selector) {
    var base = root && root.querySelectorAll ? root : document;
    var els = Array.prototype.slice.call(base.querySelectorAll(selector));
    if (root && root.matches && root.matches(selector)) els.unshift(root);
    return els;
  }

  function isLTRSurface(el) {
    return Boolean(el && el.closest && el.closest(LTR_SELECTOR));
  }

  function forceLTR(root) {
    qsa(root, LTR_SELECTOR).forEach(function (el) {
      el.dir = 'ltr';
      el.style.direction = 'ltr';
      el.style.textAlign = 'left';
      el.style.unicodeBidi = el.tagName === 'CODE' ? 'isolate' : 'embed';
    });
  }

  function applyBlockDirection(el, dir) {
    if (!dir) {
      if (el.hasAttribute('dir')) el.removeAttribute('dir');
      el.style.direction = '';
      el.style.textAlign = '';
      if (el.tagName === 'LI') el.style.listStylePosition = '';
      return;
    }

    el.dir = dir;
    el.style.direction = dir;
    el.style.textAlign = dir === 'rtl' ? 'right' : 'left';

    if (el.tagName === 'LI' && dir === 'rtl') {
      el.style.listStylePosition = 'inside';
      var parent = el.closest('ul, ol');
      if (parent && !parent.hasAttribute('dir')) {
        applyListDirection(parent, dir);
      }
    }
  }

  function applyListDirection(el, dir) {
    if (dir !== 'rtl') {
      if (el.hasAttribute('dir')) el.removeAttribute('dir');
      el.style.direction = '';
      el.style.paddingRight = '';
      el.style.paddingLeft = '';
      return;
    }

    el.dir = 'rtl';
    el.style.direction = 'rtl';
    el.style.textAlign = 'right';
    var left = getComputedStyle(el).paddingLeft;
    if (parseFloat(left) > 0) {
      el.style.paddingRight = left;
      el.style.paddingLeft = '0';
    }
  }

  function processText(root) {
    qsa(root, RTL_SELECTOR).forEach(function (el) {
      if (isLTRSurface(el)) return;
      applyBlockDirection(el, detectElDir(el));
    });

    qsa(root, 'ul, ol').forEach(function (el) {
      if (isLTRSurface(el)) return;
      applyListDirection(el, detectElDir(el));
    });
  }

  function processCompact(root) {
    qsa(root, COMPACT_SELECTOR).forEach(function (el) {
      if (isLTRSurface(el) || el.closest(EDITABLE_SELECTOR)) return;
      if (el.querySelector(RTL_SELECTOR + ', ul, ol, pre, code, table')) return;

      var text = (el.textContent || '').trim();
      if (text.length < 2) return;

      if (hasRTL(text)) {
        var dir = detectTextDir(text) || 'rtl';
        el.dir = dir;
        el.style.direction = dir;
        el.style.textAlign = dir === 'rtl' ? 'right' : 'left';
      } else if (el.hasAttribute('dir')) {
        el.removeAttribute('dir');
        el.style.direction = '';
        el.style.textAlign = '';
      }
    });
  }

  function processEditable(root) {
    qsa(root, EDITABLE_SELECTOR).forEach(function (el) {
      if (isLTRSurface(el)) return;
      var text = el.value != null ? el.value : el.textContent || el.innerText || '';
      var dir = detectTextDir(text);
      if (dir === 'rtl') {
        el.dir = 'rtl';
        el.style.direction = 'rtl';
        el.style.textAlign = 'right';
      } else if (dir === 'ltr') {
        el.dir = 'ltr';
        el.style.direction = 'ltr';
        el.style.textAlign = 'left';
      }
    });
  }

  function injectStyles() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      RTL_SELECTOR + ':not([dir]){unicode-bidi:plaintext!important;text-align:start!important}',
      '[dir="rtl"]{direction:rtl!important;text-align:right!important}',
      '[dir="ltr"]{direction:ltr!important;text-align:left!important}',
      LTR_SELECTOR + '{unicode-bidi:embed!important;direction:ltr!important;text-align:left!important}',
      'code,kbd,samp{unicode-bidi:isolate!important;direction:ltr!important}',
    ].join('\n');
    document.head.appendChild(style);
  }

  function processAll(root) {
    var target = root || document.body || document;
    processText(target);
    processCompact(target);
    processEditable(target);
    forceLTR(target);
  }

  function init() {
    injectStyles();
    processAll(document);

    document.addEventListener(
      'input',
      function (event) {
        var target = event.target;
        if (!target || !target.matches || !target.matches(EDITABLE_SELECTOR)) return;
        processEditable(target);
      },
      true
    );

    var pending = [];
    var timer = null;
    var observer = new MutationObserver(function (mutations) {
      var relevant = mutations.some(function (mutation) {
        return mutation.type === 'characterData' || mutation.addedNodes.length > 0;
      });
      if (!relevant) return;

      pending = pending.concat(mutations);
      if (timer) return;

      timer = setTimeout(function () {
        timer = null;
        var roots = new Set();
        pending.splice(0).forEach(function (mutation) {
          if (mutation.type === 'characterData' && mutation.target.parentElement) {
            roots.add(mutation.target.parentElement);
          }
          Array.prototype.forEach.call(mutation.addedNodes, function (node) {
            if (node.nodeType === Node.ELEMENT_NODE) roots.add(node);
          });
        });

        if (roots.size > 0 && roots.size <= 40) {
          roots.forEach(function (root) {
            processAll(root);
          });
        } else {
          processAll(document);
        }
      }, 60);
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
    });

    console.info('[Codex RTL] active');
  }

  try {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init, { once: true });
    } else {
      init();
    }
  } catch (error) {
    console.error('[Codex RTL]', error);
  }
})();
// --- CODEX RTL PATCH END ---
