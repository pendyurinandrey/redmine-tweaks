/* Redmine Tweaks — feature "clickable task-list checkboxes in the issue description" (needs tweaks_common.js).
 *
 * Redmine (CommonMark) renders `- [ ] item` / `- [x] item` as disabled checkboxes. This makes them clickable for users who may
 * edit the description: a click flips the n-th marker in the description source and submits Redmine's own issue form, so the
 * change goes through the normal update (version lock, history entry "Description updated", notifications).
 *
 * Safety rules (the checkboxes simply stay disabled, exactly as in stock Redmine, when a rule is not met):
 *   - the user can edit the description (the editor exists in the page);
 *   - the number of task-list markers found in the source equals the number of rendered checkboxes and every state agrees
 *     (otherwise the mapping is not trustworthy, e.g. an {{include}} macro or an unusual code block);
 *   - at click time the issue form has no other unsaved changes (a typed comment must not be sent by accident).
 *
 * Every toggle is a description update, so it adds a history entry to the issue.
 */
(function () {
  'use strict';

  // ---- pure logic (also unit-tested in node: test/task_list_toggle.test.js) ------------------------------------------------

  // Finds GFM task-list markers in CommonMark source, in document order, skipping fenced code blocks.
  // Returns [{ pos, checked }], where pos is the index of the character between the brackets.
  function findTaskMarkers(text) {
    var markers = [];
    var offset = 0;
    var fence = null;
    text.split('\n').forEach(function (line) {
      var body = line.replace(/\r$/, '');
      var f = /^\s*(`{3,}|~{3,})/.exec(body);
      if (fence) {
        // a closing fence: the same character, at least as long, nothing else on the line
        if (f && f[1].charAt(0) === fence.ch && f[1].length >= fence.len && /^\s*(`+|~+)\s*$/.test(body)) { fence = null; }
      } else if (f) {
        fence = { ch: f[1].charAt(0), len: f[1].length };
      } else {
        // optional blockquote markers, indentation, a list marker (-, *, + or 1. / 1)), then [ ] / [x] / [X] and a space or the end
        var m = /^((?:\s*>)*\s*(?:[-*+]|\d{1,9}[.)])\s+)\[([ xX])\](?=\s|$)/.exec(body);
        if (m) { markers.push({ pos: offset + m[1].length + 1, checked: m[2] !== ' ' }); }
      }
      offset += line.length + 1;
    });
    return markers;
  }

  // Returns the source with the given marker set to the requested state; everything else stays byte for byte.
  function setMarker(text, marker, checked) {
    return text.slice(0, marker.pos) + (checked ? 'x' : ' ') + text.slice(marker.pos + 1);
  }

  var api = { findTaskMarkers: findTaskMarkers, setMarker: setMarker };
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }

  // ---- browser part -------------------------------------------------------------------------------------------------------

  var RESTORE_KEY = 'redmine-tweaks-restore-scroll';
  var t = window.RedmineTweaks.t;
  var isDirty = window.RedmineTweaks.isDirty;

  // After the form submit Redmine redirects to the issue page: put the reader back where they were
  function restoreScroll() {
    try {
      var saved = JSON.parse(window.sessionStorage.getItem(RESTORE_KEY) || 'null');
      window.sessionStorage.removeItem(RESTORE_KEY);
      if (saved && saved.path === window.location.pathname) { window.scrollTo(0, saved.y); }
    } catch (e) { /* storage unavailable: nothing to restore */ }
  }

  function init() {
    restoreScroll();

    var wiki  = document.getElementById('issue_description_wiki');
    var field = document.getElementById('issue_description');   // exists only for users who may edit the description
    var form  = document.getElementById('issue-form');
    if (!wiki || !field || !form) { return; }

    var boxes = Array.prototype.slice.call(wiki.querySelectorAll('input.task-list-item-checkbox'));
    if (!boxes.length) { return; }
    var markers = findTaskMarkers(field.defaultValue);
    var trustworthy = markers.length === boxes.length && boxes.every(function (box, i) { return box.checked === markers[i].checked; });
    if (!trustworthy) { return; }                                // stay read-only, as in stock Redmine

    var saving = false;
    boxes.forEach(function (box, i) {
      box.disabled = false;
      box.classList.add('rt-task-toggle');
      box.addEventListener('change', function () {
        var wanted = box.checked;
        function revert() { box.checked = !wanted; }
        if (saving) { revert(); return; }
        if (isDirty(form)) {
          revert();
          window.alert(t('checklist_unsaved_changes', 'The issue form has unsaved changes. Save or discard them first, then toggle the checkbox.'));
          return;
        }
        saving = true;
        boxes.forEach(function (b) { b.disabled = true; });      // no second click while the request is on its way
        field.value = setMarker(field.defaultValue, markers[i], wanted);
        try { window.sessionStorage.setItem(RESTORE_KEY, JSON.stringify({ path: window.location.pathname, y: window.scrollY })); } catch (e) { /* ignore */ }
        if (form.requestSubmit) { form.requestSubmit(); } else { form.submit(); }
      });
    });
  }

  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', init); } else { init(); }
})();
